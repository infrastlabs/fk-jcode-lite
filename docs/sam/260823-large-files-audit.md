# 仓库大文件审计报告 (≥ 1 MiB)

- **审计日期**: 2026-08-22
- **扫描范围**: 工作区 + Git 历史全部分支
- **仓库**: `fk-jcode` (branch: `sam-custom`)

---

## 一、工作区大文件清单 (16 个, ≈ 173.1 MiB)

### 🎬 视频 MP4 (13 个 / 126.8 MiB)

| # | 大小 (bytes) | 大小 (MiB) | 路径 |
|---|---:|---:|---|
| 1 | 25,357,788 | 24.17 | `assets/demos/jcode-claudeai-demo.mp4` |
| 2 | 19,243,301 | 18.37 | `assets/demos/exports/memory_demo_1m40_spedup.mp4` |
| 3 | 16,785,949 | 16.01 | `assets/demos/exports/memory_demo_1m40_spedup_v2.mp4` |
| 4 | 16,785,949 | 16.01 | `assets/demos/memory_demo.mp4` |
| 5 | 11,753,989 | 11.21 | `assets/demos/jcode_wolf_demo_final.mp4` |
| 6 | 11,055,874 | 10.54 | `assets/demos/jcode_wolf_demo_v2.mp4` |
| 7 | 4,899,092 | 4.67 | `assets/demos/jcode_replay_duck_fast-on-mid-stream_autoedit_2x.mp4` |
| 8 | 2,961,166 | 2.83 | `assets/demos/jcode_demo.mp4` |
| 9 | 2,592,838 | 2.47 | `assets/demos/jcode_replay_duck_fast-on-mid-stream_autoedit_trimmed_2x.mp4` |
| 10 | 2,592,838 | 2.47 | `assets/demos/workflow.mp4` |
| 11 | 1,257,337 | 1.20 | `assets/demos/jcode_mermaid_demo.mp4` |
| 12 | 1,257,337 | 1.20 | `assets/demos/jcode_mermaid_demo_final.mp4` |
| 13 | 1,090,810 | 1.04 | `assets/demos/jcode_mermaid_demo_v2.mp4` |

### 🖼️ GIF 动画 (1 个 / 54.4 MiB)

| # | 大小 (bytes) | 大小 (MiB) | 路径 |
|---|---:|---:|---|
| 1 | 57,093,402 | 54.40 | `assets/readme/100-sessions-spawn-demo.gif` |

### 🎨 图标 (1 个 / 1.9 MiB)

| # | 大小 (bytes) | 大小 (MiB) | 路径 |
|---|---:|---:|---|
| 1 | 1,983,704 | 1.89 | `assets/app-icons/Jcode.icns` |

### 🔤 字体 (1 个 / 1.1 MiB)

| # | 大小 (bytes) | 大小 (MiB) | 路径 |
|---|---:|---:|---|
| 1 | 1,124,540 | 1.08 | `crates/jcode-math/assets/STIXTwoMath-Regular.ttf` |

---

## 二、Git 历史大 blob 汇总 (40 个 / 340.95 MiB)

> 包含已删除但仍存在于历史中的文件。

### 类别汇总

| 类别 | 个数 | 总大小 (MiB) | 占比 |
|---|---:|---:|---:|
| 🎬 视频 MP4 | 13 | 96.23 | 28.2% |
| 🖼️ GIF 动画 | 3 | 167.01 | 49.0% |
| 🍎 iOS 构建缓存 (.pcm ModuleCache) | 15 | 60.56 | 17.8% |
| 📦 iOS 构建缓存 (.swiftinterface / 二进制 / dSYM) | 6 | 11.16 | 3.3% |
| 🔤 字体 | 2 | 4.09 | 1.2% |
| 🎨 图标 | 1 | 1.89 | 0.6% |
| **合计** | **40** | **340.95** | **100%** |

### 历史全量明细 (按大小降序)

| # | 大小 (bytes) | 大小 (MiB) | 路径 | 类别 |
|---|---:|---:|---|---|
| 1 | 90,740,784 | 86.47 | `assets/readme/jcode-performance-demonstration.gif` | GIF (已删除) |
| 2 | 57,093,402 | 54.40 | `assets/readme/100-sessions-spawn-demo.gif` | GIF |
| 3 | 27,286,052 | 26.00 | `assets/readme/jcode-performance-demonstration.gif` | GIF (已删除, 旧版本) |
| 4 | 25,357,788 | 24.17 | `assets/demos/jcode-claudeai-demo.mp4` | 视频 |
| 5 | 19,243,301 | 18.37 | `assets/demos/exports/memory_demo_1m40_spedup.mp4` | 视频 |
| 6 | 16,785,949 | 16.01 | `assets/demos/exports/memory_demo_1m40_spedup_v2.mp4` | 视频 |
| 7 | 16,785,949 | 16.01 | `assets/demos/memory_demo.mp4` | 视频 |
| 8 | 11,753,989 | 11.21 | `assets/demos/jcode_wolf_demo_final.mp4` | 视频 |
| 9 | 11,055,874 | 10.54 | `assets/demos/jcode_wolf_demo_v2.mp4` | 视频 |
| 10 | 6,939,920 | 6.62 | `ios/.build/.../ModuleCache/.../Foundation-...pcm` | iOS 缓存 |
| 11 | 6,798,192 | 6.48 | `ios/.build/.../ModuleCache/.../Foundation-...pcm` | iOS 缓存 |
| 12 | 5,789,592 | 5.52 | `ios/.build/.../ModuleCache/.../Darwin-...pcm` | iOS 缓存 |
| 13 | 5,766,688 | 5.50 | `ios/.build/.../ModuleCache/.../Darwin-...pcm` | iOS 缓存 |
| 14 | 5,765,760 | 5.50 | `ios/.build-ios/.../ModuleCache/.../Foundation-...pcm` | iOS 缓存 |
| 15 | 4,899,092 | 4.67 | `assets/demos/jcode_replay_duck_fast-on-mid-stream_autoedit_2x.mp4` | 视频 |
| 16 | 4,607,712 | 4.39 | `ios/.build/.../ModuleCache/.../CoreServices-...pcm` | iOS 缓存 |
| 17 | 4,512,568 | 4.30 | `ios/.build/.../ModuleCache/.../CoreServices-...pcm` | iOS 缓存 |
| 18 | 4,379,064 | 4.17 | `ios/.build/.../ModuleCache/.../IOKit-...pcm` | iOS 缓存 |
| 19 | 4,371,096 | 4.17 | `ios/.build/.../ModuleCache/.../IOKit-...pcm` | iOS 缓存 |
| 20 | 3,984,256 | 3.80 | `ios/.build-ios/.../ModuleCache/.../Darwin-...pcm` | iOS 缓存 |
| 21 | 3,267,640 | 3.12 | `ios/.build/.../ModuleCache/.../Security-...pcm` | iOS 缓存 |
| 22 | 3,184,640 | 3.03 | `ios/.build/.../ModuleCache/.../Security-...pcm` | iOS 缓存 |
| 23 | 3,165,816 | 3.02 | `crates/jcode-desktop/assets/fonts/Gaegu-Regular.ttf` | 字体 (已删除) |
| 24 | 3,145,083 | 3.00 | `ios/.build/.../JCodeKitPackageTests.dSYM/...` | iOS 缓存 |
| 25 | 3,116,095 | 2.97 | `ios/.build/.../JCodeKitPackageTests.dSYM/...` | iOS 缓存 |
| 26 | 2,961,166 | 2.83 | `assets/demos/jcode_demo.mp4` | 视频 |
| 27 | 2,592,838 | 2.47 | `assets/demos/jcode_replay_duck_fast-on-mid-stream_autoedit_trimmed_2x.mp4` | 视频 |
| 28 | 2,592,838 | 2.47 | `assets/demos/workflow.mp4` | 视频 |
| 29 | 1,983,704 | 1.89 | `assets/app-icons/Jcode.icns` | 图标 |
| 30 | 1,508,025 | 1.44 | `jcode_replay_jaguar_20260220_115340.mp4` | 视频 (已删除) |
| 31 | 1,481,416 | 1.41 | `ios/.build/.../index/store/v5/records/.../arm64e-apple-macos.swiftinterface-...` | iOS 缓存 |
| 32 | 1,472,324 | 1.40 | `ios/.build-ios/.../index/store/v5/records/.../arm64-apple-ios-simulator.swiftinterface-...` | iOS 缓存 |
| 33 | 1,424,480 | 1.36 | `ios/.build/.../ModuleCache/.../CoreFoundation-...pcm` | iOS 缓存 |
| 34 | 1,397,560 | 1.33 | `ios/.build/.../ModuleCache/.../CoreFoundation-...pcm` | iOS 缓存 |
| 35 | 1,313,432 | 1.25 | `ios/.build-ios/.../ModuleCache/.../CoreFoundation-...pcm` | iOS 缓存 |
| 36 | 1,293,982 | 1.23 | `assets/demos/jcode_mermaid_demo.mp4` | 视频 (旧版本) |
| 37 | 1,261,928 | 1.20 | `ios/.build/.../JCodeKitPackageTests` | iOS 缓存 |
| 38 | 1,257,337 | 1.20 | `assets/demos/jcode_mermaid_demo.mp4` | 视频 |
| 39 | 1,227,640 | 1.17 | `ios/.build/.../JCodeKitPackageTests` | iOS 缓存 |
| 40 | 1,124,540 | 1.08 | `crates/jcode-math/assets/STIXTwoMath-Regular.ttf` | 字体 |

---

## 三、关键发现

### 1. iOS 构建缓存被误提交 (71.7 MiB / 21 个 blob)

`ios/.build/` 和 `ios/.build-ios/` 下的编译产物（ModuleCache `.pcm`、`.swiftinterface`、dSYM、可执行二进制）已被提交到 Git 历史。工作区当前已清理，但历史中仍有 21 个 blob。这些文件属于构建中间产物，不应进入版本管理。

### 2. 历史 GIF 动画体积最大 (167.0 MiB)

已删除的 `assets/readme/jcode-performance-demonstration.gif` 在历史中残留两个版本（86.5 MiB + 26.0 MiB），是历史中最重的单个文件类别。

### 3. 演示视频占 96.2 MiB

13 个 MP4 文件，多为产品演示录屏，工作区仍保留。

### 4. Git LFS 未启用

所有二进制以普通 blob 存储。若历史不清洗，仓库对象库体积将持续膨胀。

---

## 四、清理脚本使用方法

配套脚本位于同目录: **`260823-large-files-cleanup.sh`** (367 行, 已 `chmod +x`)

### 前置准备

以下命令已在当前服务器 (Ubuntu 22.04 / ARM64) 验证通过，**root 可免密 sudo**：

```bash
# 1. 安装 OpenJDK 11
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-11-jdk-headless

# 验证:
java -version
# openjdk version "11.0.31"

# 2. 安装 BFG Repo-Cleaner (官方 jar, 不走 apt 源)
sudo wget -q \
  https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar \
  -O /usr/local/bin/bfg.jar

# 创建 wrapper 脚本 (bfg.jar 不能直接执行, 需要 java -jar)
sudo tee /usr/local/bin/bfg > /dev/null << 'EOF'
#!/bin/bash
exec java -jar /usr/local/bin/bfg.jar "$@"
EOF
sudo chmod +x /usr/local/bin/bfg

# 验证:
bfg --version
# bfg 1.14.0

# 3. 同步最新代码
cd /path/to/fk-jcode
git pull --rebase origin sam-custom
```

### 执行清理

```bash
./docs/sam/260823-large-files-cleanup.sh
```

脚本交互流程:

| 步骤 | 操作 | 效果 |
|---|---|---|
| **前置检查** | 检测 BFG / Java / 工作区状态 | 不干净则自动 stash |
| **Step 1 — 搬移** | 工作区 ≥1MiB 文件 → `../fk-jcode-dropBig/` (保留目录结构) | `crates/` 下字体等保留不动 |
| **Step 2 — git rm** | 从索引移除已搬移文件并提交 | 产生 `chore: remove large binary assets` commit |
| **Step 3 — BFG** | `bfg -b 1M` 删除全部历史中 ≥1MiB 的 blob，然后 `git add` 回 `crates/` 下保留的字体 | 从所有分支历史中剥离大文件，保留 `crates/` 资源 |
| **Step 4 — gc** | `reflog expire --all` + `git gc --prune=now --aggressive` | 压缩对象库，显示前后大小对比 |
| **Step 5 — 验证** | 扫描确认无残留 | 列出保留的 `crates/` 文件 |

### 清理范围

| 路径模式 | 动作 |
|---|---|
| `ios/.build*/` | ❌ 删除 (iOS 构建缓存) |
| `ios/.build-ios*/` | ❌ 删除 |
| `jcode_replay*.mp4` | ❌ 删除 (根目录录屏) |
| `assets/readme/*.gif` | ❌ 删除 (演示 GIF) |
| `assets/demos/**/*.mp4` | ❌ 删除 (演示视频) |
| `assets/app-icons/Jcode.icns` | ❌ 删除 (图标) |
| `crates/**/*` | ✅ **保留** (字体等必需资源) |

### 清理后操作

```bash
# 强制推送 (改写历史)
git push --force origin sam-custom

# 通知团队 rebase
# 告知团队成员: git fetch origin && git rebase origin/sam-custom
```

### 回滚

所有被搬移的文件保留在 `../fk-jcode-dropBig/` 中，按需 `mv` 回仓库即可。

---

## 五、建议措施

| 优先级 | 措施 | 说明 |
|---|---|---|
| 🔴 立即 | 确认 `.gitignore` 排除 `ios/.build*/` | 工作区已清理，但需确保后续不会再次提交 |
| 🟡 短期 | 迁移 `assets/demos/*.mp4` 和 `assets/readme/*.gif` 到 Git LFS 或对象存储 (S3 / OSS / Release Asset) | 从 Git 中移除后大幅减小 clone 体积 |
| 🟡 短期 | 清理重复/旧版本演示文件 | 如 `mermaid_demo.mp4` 与 `mermaid_demo_final.mp4`、`mermaid_demo_v2.mp4` 重复；`memory_demo.mp4` 与 `exports/` 下版本重复 |
| 🟢 长期 | 使用 BFG Repo-Cleaner 或 `git filter-repo` 重写历史，彻底移除 `ios/.build*/` 和已删除的大文件 | 需团队协作，强制推送前通知全员 |
| 🟢 长期 | 启用 Git LFS 管理所有二进制资产 | 后续所有大文件自动走 LFS 存储 |

---

## 七、清理结果

### 执行状态 (2026-08-23)

| 项目 | 清理前 | 清理后 |
|---|---:|---:|
| `.git` 对象库 | **356 MiB** | **38 MiB** (↓ 89%) |
| 历史大 blob | 40 个 | **1 个** (`crates/jcode-math/assets/STIXTwoMath-Regular.ttf`, 已保留) |
| 工作区 ≥1MiB 文件 | 15 个 | **0 个** (全部搬移) |
| 搬移目标 | — | `../fk-jcode-dropBig/` (15 个文件, 169 MiB) |

### 搬移文件清单 (`../fk-jcode-dropBig/`)

| 大小 (MiB) | 路径 |
|---:|---|
| 54.45 | `assets/readme/100-sessions-spawn-demo.gif` |
| 24.18 | `assets/demos/jcode-claudeai-demo.mp4` |
| 18.35 | `assets/demos/exports/memory_demo_1m40_spedup.mp4` |
| 16.01 | `assets/demos/exports/memory_demo_1m40_spedup_v2.mp4` |
| 16.01 | `assets/demos/memory_demo.mp4` |
| 11.21 | `assets/demos/jcode_wolf_demo_final.mp4` |
| 10.54 | `assets/demos/jcode_wolf_demo_v2.mp4` |
| 4.67 | `assets/demos/jcode_replay_duck_fast-on-mid-stream_autoedit_2x.mp4` |
| 2.82 | `assets/demos/jcode_demo.mp4` |
| 2.47 | `assets/demos/jcode_replay_duck_fast-on-mid-stream_autoedit_trimmed_2x.mp4` |
| 2.47 | `assets/demos/workflow.mp4` |
| 1.20 | `assets/demos/jcode_mermaid_demo_final.mp4` |
| 1.20 | `assets/demos/jcode_mermaid_demo.mp4` |
| 1.04 | `assets/demos/jcode_mermaid_demo_v2.mp4` |
| 1.89 | `assets/app-icons/Jcode.icns` |

### 清理流程记录

| 步骤 | 操作 | 结果 |
|---|---|---|
| 1. 搬移 | `mv` 15 个工作区大文件 → `../fk-jcode-dropBig/` | `crates/STIXTwoMath-Regular.ttf` 保留不动 |
| 2. git rm | `git rm` + `git commit` | 产生 `chore: remove large binary assets` commit |
| 3. BFG | `bfg -b 1M` 删除历史中所有 ≥1MiB 的 blob | 15930 个 object id 被改写 |
| 4. gc | `reflog expire --all` + `git gc --prune=now --aggressive` | 356 MiB → 38 MiB |
| 5. 验证 | 扫描历史 + 工作区 | 仅剩 1 个 `crates/` 字体 |

### 分支状态

| 分支 | HEAD | `.git` 大小 | 说明 |
|---|---|---:|---|
| `sam-custom` | `291fbbe14` | ~356 MiB (未清理) | 主分支, 保留原始历史 |
| `sam-lite` | `e3fcd469b` | **38 MiB** | 已清理, 单独推送至 `fk-jcode-lite` |

---

## 八、数据附录

```
历史 blob ≥1MiB: 40 个, 总计 357,508,581 bytes (340.95 MiB)
工作区文件 ≥1MiB: 16 个, 总计 182,244,386 bytes (173.73 MiB)

类别分布:
  GIF 动画          3 个  167.01 MiB  49.0%
  视频 MP4         13 个   96.23 MiB  28.2%
  iOS .pcm         15 个   60.56 MiB  17.8%
  iOS 其他         6 个    11.16 MiB   3.3%
  字体             2 个    4.09 MiB   1.2%
  图标             1 个    1.89 MiB   0.6%
```
