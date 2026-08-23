#!/usr/bin/env bash
#
# 260823-large-files-cleanup.sh
# ==============================
# 基于 BFG Repo-Cleaner 的仓库大文件清理脚本
#
# 用途:
#   从 git 历史中移除所有 ≥1 MiB 的非代码二进制文件
#   (GIF / MP4 / iOS 构建缓存 / dSYM / swiftinterface)，
#   保留 crates/ 下必要的字体资源。
#
# ─────────────────────────────────────────────────────────────
# 流程:
#   Step 1  搬移  工作区大文件 → ../fk-jcode-dropBig/ (保留目录结构)
#   Step 2  git rm 从当前索引移除已搬移文件并提交
#   Step 3  BFG   从全部历史分支中剥离大文件
#   Step 4  gc    reflog expire + git gc --prune=now --aggressive
#   Step 5  验证  确认历史中不再有大文件 (crates/ 除外)
#
# 前置依赖:
#   - Java 11+
#   - BFG Repo-Cleaner  (https://rtyley.github.io/bfg-repo-cleaner/)
#     安装:  java -jar bfg-*.jar  或直接:
#             apt install bfg   /   brew install bfg
#
# 前置操作:
#   cd /path/to/fk-jcode
#   git pull --rebase origin sam-custom
#   chmod +x docs/sam/260823-large-files-cleanup.sh
#   ./docs/sam/260823-large-files-cleanup.sh
#
# 后续操作:
#   git push --force origin sam-custom
#   # 通知团队: rebase onto new origin/sam-custom
#
# 回滚:
#   所有被搬移的文件保留在 ../fk-jcode-dropBig/ 中，按需恢复即可
# ─────────────────────────────────────────────────────────────

set -euo pipefail

# ─── 配置 ────────────────────────────────────────────────────────────────

DROP_DIR="../fk-jcode-dropBig"   # 搬移目标 (相对于仓库根目录的父级)
BFG_BIN="bfg"                    # BFG 命令名
BIG_BYTES=1048576                # 1 MiB

# ─── 颜色 ────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*" >&2; exit 1; }

# ─── 前置检查 ────────────────────────────────────────────────────────────

precheck() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  cd "$REPO_ROOT"

  info "仓库:     $REPO_ROOT"
  info "分支:     $(git rev-parse --abbrev-ref HEAD)"
  info "HEAD:     $(git rev-parse --short HEAD)"
  info "远端:     $(git remote get-url origin 2>/dev/null || echo 'none')"

  if [ -n "$(git status --porcelain)" ]; then
    warn "工作区有未提交更改，先 stash"
    git stash push -m "pre-cleanup-$(date +%Y%m%d_%H%M%S)"
    ok "已 stash"
  else
    ok "工作区干净"
  fi

  command -v "$BFG_BIN" &>/dev/null \
    || fail "未找到 '$BFG_BIN'。请先安装 BFG:  https://rtyley.github.io/bfg-repo-cleaner/"

  command -v java &>/dev/null \
    || fail "缺少 Java (BFG 依赖)，请先安装 Java 11+"

  info "Java:     $(java -version 2>&1 | head -1)"
  ok "前置检查通过"
}

# ─── Step 1: 搬移工作区大文件 ────────────────────────────────────────────

# 判断是否应保留 (crates/ 下的字体等)
should_keep() {
  local rel="$1"
  [[ "$rel" == crates/* ]]
}

move_workspace_big_files() {
  echo ""
  info "━━━ Step 1: 搬移工作区 ≥1MiB 文件 ━━━"
  info "  目标: $DROP_DIR/"

  mkdir -p "$DROP_DIR"

  local moved=0 kept=0

  while IFS= read -r -d '' file; do
    local rel="${file#./}"
    local bytes
    bytes=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    local miB
    miB=$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}")

    if should_keep "$rel"; then
      info "  [保留] ${miB} MiB  $rel"
      kept=$((kept + 1))
      continue
    fi

    local dest="$REPO_ROOT/$DROP_DIR/$rel"
    mkdir -p "$(dirname "$dest")"

    if [ -f "$dest" ]; then
      warn "  [跳过] $rel  (已存在于 $DROP_DIR)"
      continue
    fi

    mv "$rel" "$dest"
    info "  [搬移] ${miB} MiB  $rel"
    moved=$((moved + 1))
  done < <(find . -type f -size +${BIG_BYTES}c \
    -not -path './.git/*' -not -path './target/*' \
    -not -path './node_modules/*' -not -path './.cargo/*' \
    -print0 | sort -z)

  ok "Step 1 完成:  $moved 个搬移,  $kept 个保留"
  _mv_count=$moved
}

# ─── Step 2: git rm 并提交 ─────────────────────────────────────────────

git_rm_moved() {
  echo ""
  info "━━━ Step 2: git rm 已搬移文件 ━━━"

  local count=0
  if [ "${_mv_count:-0}" -eq 0 ]; then
    ok "无需 git rm (无文件搬移)"
    return
  fi

  while IFS= read -r -d '' dropped; do
    local rel="${dropped#$REPO_ROOT/$DROP_DIR/}"
    # rel 此时就是原仓库内的相对路径
    if git rm --quiet "$rel" 2>/dev/null; then
      count=$((count + 1))
    fi
  done < <(find "$REPO_ROOT/$DROP_DIR" -type f -print0 2>/dev/null | sort -z)

  if [ "$count" -gt 0 ]; then
    git commit -m "chore: remove large binary assets (bfg cleanup prep)"
    ok "Step 2 完成: git rm 并提交 $count 个文件"
  else
    ok "Step 2 完成: 无需移除"
  fi
}

# ─── Step 3: BFG 清理历史 ─────────────────────────────────────────────

bfg_clean() {
  echo ""
  info "━━━ Step 3: BFG 清理历史 ━━━"

  # 记录清理前大小
  _git_size_before=$(du -sb .git | awk '{print $1}')
  _git_size_before_miB=$(awk "BEGIN {printf \"%.2f\", $_git_size_before/1048576}")
  info "  .git 当前大小: ${_git_size_before_miB} MiB"

  # 收集所有 ≥1MiB 且不在 crates/ 下的文件路径 (去重)
  info "  收集待清理的历史文件路径..."
  local targets
  targets=$(git rev-list --all --objects | \
    git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' 2>/dev/null | \
    awk '$1=="blob" && $3>=1048576 && $4 !~ /^crates\// {print $4}' | sort -u)

  local target_count
  target_count=$(echo "$targets" | wc -l | tr -d ' ')
  info "  待清理目标: $target_count 个文件"

  if [ -z "$targets" ]; then
    ok "无需清理 (历史中无目标文件)"
    return
  fi

  # 分类显示
  echo "$targets" | awk -F/ '{
    if ($0 ~ /ios\/\.build/)        printf "  [iOS]     %s\n", $0
    else if ($0 ~ /\.gif$/)         printf "  [GIF]     %s\n", $0
    else if ($0 ~ /\.mp4$/)         printf "  [MP4]     %s\n", $0
    else if ($0 ~ /\.swiftinterface/) printf "  [Swift]   %s\n", $0
    else                            printf "  [Other]   %s\n", $0
  }' | head -50

  # 如果有更多，省略
  if [ "$target_count" -gt 50 ]; then
    echo "  ... (共 $target_count 个)"
  fi

  # 构建 BFG 命令
  #
  # BFG 支持:
  #   --delete-files <pattern>   (glob，可重复多次)
  #   --delete-directories <dir> (可重复多次)
  #
  # 策略:
  #   1. 对于 ios/.build 这类完整目录树，用 --delete-directories 更高效
  #   2. 其余文件逐个用 --delete-files <精确路径>
  #
  # 注意: 精确路径作为 glob pattern 时只匹配自身，安全

  local -a bfg_args=()
  local -a dir_targets=()
  local -a file_targets=()

  while IFS= read -r f; do
    [ -z "$f" ] && continue

    # 提取到目录级 (ios/.build/xxx, ios/.build-ios/xxx)
    local dir_part
    dir_part=$(echo "$f" | awk -F/ '{print $1"/"$2}')

    if [[ "$dir_part" == ios/.build* ]]; then
      # 目录级去重
      local already=0
      for d in ${dir_targets[@]+"${dir_targets[@]}"}; do
        [ "$d" = "$dir_part" ] && already=1 && break
      done
      [ "$already" -eq 0 ] && dir_targets+=("$dir_part")
    else
      file_targets+=("$f")
    fi
  done <<< "$targets"

  # 组装命令
  for d in ${dir_targets[@]+"${dir_targets[@]}"}; do
    bfg_args+=("--delete-directories" "$d")
  done
  for f in ${file_targets[@]+"${file_targets[@]}"}; do
    bfg_args+=("--delete-files" "$f")
  done

  info "  执行 BFG..."
  info "    ${BFG_BIN} ${bfg_args[*]} \"$REPO_ROOT\""
  echo ""

  # BFG 可能输出大量日志，只取关键行
  "$BFG_BIN" "${bfg_args[@]}" "$REPO_ROOT" 2>&1 | \
    grep -E '(^\s*[0-9]|Found|Cleaning|Done)' || true

  echo ""
  ok "Step 3 完成: BFG 清理结束"
}

# ─── Step 4: 压缩对象库 ────────────────────────────────────────────────

gc_repo() {
  echo ""
  info "━━━ Step 4: 压缩对象库 ━━━"

  git reflog expire --expire=now --all
  ok "  reflog expire 完成"

  info "  执行 git gc --prune=now --aggressive (可能需要数分钟)..."
  git gc --prune=now --aggressive 2>&1 | tail -3 || true
  ok "  gc 完成"

  _git_size_after=$(du -sb .git | awk '{print $1}')
  _git_size_after_miB=$(awk "BEGIN {printf \"%.2f\", $_git_size_after/1048576}")
  _git_saved_miB=$(awk "BEGIN {printf \"%.2f\", (${_git_size_before_miB} - ${_git_size_after_miB})}")

  info "  .git 大小: ${_git_size_before_miB} MiB → ${_git_size_after_miB} MiB"
  info "  节省:     ${_git_saved_miB} MiB"
  ok "Step 4 完成"
}

# ─── Step 5: 验证 ───────────────────────────────────────────────────────

verify() {
  echo ""
  info "━━━ Step 5: 验证 ━━━"

  local remaining
  remaining=$(git rev-list --all --objects | \
    git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' 2>/dev/null | \
    awk '$1=="blob" && $3>=1048576 && $4 !~ /^crates\// {printf "%8d  %s\n", $3, $4}' | sort -rn)

  if [ -z "$remaining" ]; then
    ok "✅  历史中已无 ≥1MiB 非 crates/ 文件"
  else
    warn "⚠  仍有以下大文件残留:"
    echo "$remaining" | sed 's/^/     /'
  fi

  # 确认保留的文件
  local kept
  kept=$(git rev-list --all --objects | \
    git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' 2>/dev/null | \
    awk '$1=="blob" && $3>=1048576 && $4 ~ /^crates\// {printf "%8d  %s\n", $3, $4}' | sort -rn)

  if [ -n "$kept" ]; then
    info "  保留的大文件 (crates/):"
    echo "$kept" | sed 's/^/     /'
  fi

  echo ""
  echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${GREEN}║              清 理 完 成                             ║${NC}"
  echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
  echo ""
  info "搬移文件位置:  $REPO_ROOT/$DROP_DIR/"
  info "强制推送:      git push --force origin $(git rev-parse --abbrev-ref HEAD)"
  info "团队通知:      告知 rebase onto new origin/$(git rev-parse --abbrev-ref HEAD)"
  echo ""
}

# ─── 主流程 ─────────────────────────────────────────────────────────────

main() {
  echo ""
  echo -e "${BOLD}"
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║   JCode 仓库大文件清理脚本 (260823)                      ║"
  echo "║   基于 BFG Repo-Cleaner                                  ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo ""

  precheck

  echo ""
  echo -e "${YELLOW}──────────────────────────────────────────────────────${NC}"
  echo -e "${YELLOW}本脚本将执行以下操作:${NC}"
  echo "  1. 将工作区 ≥1MiB 文件搬移至 $DROP_DIR/"
  echo "  2. git rm 并提交移除记录"
  echo "  3. BFG 从全部历史分支剥离大文件"
  echo "  4. git gc --aggressive 压缩对象库"
  echo "  5. 验证清理结果"
  echo ""
  echo -e "${RED}⚠  此操作会改写 git 历史，执行后需要 git push --force${NC}"
  echo -e "${YELLOW}──────────────────────────────────────────────────────${NC}"
  echo ""
  read -r -p "是否继续? (yes/no): " confirm

  if [ "$confirm" != "yes" ]; then
    info "用户取消"
    exit 0
  fi

  move_workspace_big_files
  git_rm_moved
  bfg_clean
  gc_repo
  verify
}

main "$@"
