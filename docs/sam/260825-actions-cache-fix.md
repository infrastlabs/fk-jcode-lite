# GitHub Actions 缓存问题分析（2026-08-25 12:10 追加）

## 一、问题现象

release.yml 构建 job 的 post 缓存步骤上传内容极少、几乎没有，上传速度显示 0 MB/s。

## 二、根因

**缓存路径与实际构建读写路径完全不在一个地方。** 当前矩阵唯一启用的 target 是 `compat_container: true`，普通构建步骤全被 `if: matrix.compat_container != true` 跳过（release.yml 165、205 行），实际执行的是 `scripts/build_linux_compat.sh dist`（release.yml 197 行）。

### 2.1 路径不匹配对照表

| 资源 | actions/cache 缓存的路径 | 实际写入路径 | 匹配 |
|------|------------------------|-------------|------|
| 编译产物 | `target/x86_64-unknown-linux-gnu/release/deps` | `CARGO_TARGET_DIR=/work/target/linux-compat` → `target/linux-compat/x86_64-unknown-linux-gnu/release/deps` | ❌ |
| cargo registry | `~/.cargo/registry` | `~/.cache/jcode-linux-compat/cargo-registry`（bind mount 进容器当 `/root/.cargo/registry`） | ❌ |
| cargo git | `~/.cargo/git` | `~/.cache/jcode-linux-compat/cargo-git` | ❌ |

### 2.2 结论

post 步骤去 tar 的目录在宿主机上要么不存在、要么是空的（普通构建从没跑过）→ 上传内容趋近于零 → 0 MB/s。

## 三、连带问题

1. **sccache 在 compat 路径完全失效**：`RUSTC_WRAPPER=sccache` 只在"Build release binary"分支设置（179-181 行），实际执行的 compat 分支在容器内构建，容器里没装 sccache，env 也没传进去。
2. **缓存 key 没拼 target**：`key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}`，注释里自己写了"关键修正：把 matrix.target 动态拼进去"但对 key 没生效，若将来启用多 target 会互踩缓存。
3. **缓存核心价值丢失**：compat 构建每 60 分钟超时里大头就是容器内装工具链 + 全量编译依赖，本来该缓存的 `target/linux-compat` + `~/.cache/jcode-linux-compat` 一个都没缓存到。

## 四、修复方向（未开工，仅分析）

### 方案 1：缓存路径跟随脚本

把 actions/cache 的 path 改成真实路径：

```yaml
path: |
  target/linux-compat
  ~/.cache/jcode-linux-compat/cargo-registry
  ~/.cache/jcode-linux-compat/cargo-git
```

**✅ 已实施（2026-08-25 12:14，提交 `1378a4e78`）**。实际改动：

- cache path 改为 `~/.cache/jcode-linux-compat/{cargo-registry,cargo-git}` + `target/linux-compat/<target>/release/{deps,build}`（只缓 deps/build，不缓整个 target，维持旧策略的减体思路）
- cache key 从 `-cargo-` 改为 `-cargo-compat-`，避免与旧的空缓存 key 冲突
- `build_linux_compat.sh` 容器内末尾新增 `chown -R HOST_UID:HOST_GID "$CARGO_TARGET_DIR" /root/.cargo/{registry,git}`：容器内 root 创建的产物和 cargo 缓存落在宿主 bind mount 上但属主是 root，若不 chown 回 runner 用户，post-cache tar 仍会 Permission denied，缓存照样存不上（这是 0 MB/s 的第二个根因，原分析遗漏）
- 语法验证：`bash -n` 与 YAML 解析均通过
- 待观察：下一条 push 到 sam-lite 跑 release workflow 的 post-cache 上传量是否常态化（应出现几百 MB 而非 0 MB/s）

### 方案 2：让脚本跟上普通布局

给 `build_linux_compat.sh` 传 `JCODE_COMPAT_CACHE_DIR=~/.cargo`，或把 `CARGO_TARGET_DIR` 指回 `target/${{ matrix.target }}`，让现有缓存配置直接命中。

**注意**：方案 2 改动小，但要处理容器内目标目录所有权与 tar 权限问题（release.yml 注释里的 Permission denied 踩坑史同源，旧方案 1~5 全失败才改的缓存策略）。

## 五、相关代码位置

- `release.yml` 缓存配置：140-156 行
- `release.yml` compat 分支：194-202 行
- `scripts/build_linux_compat.sh` target 目录：145 行
- `scripts/build_linux_compat.sh` cache_root：23 行、91-93 行
## 六、sccache 分析（2026-08-25 20:20 追加）

### 1. 现状：compat 路径下 sccache 完全无效

- `Setup sccache` 在宿主机跑（release.yml 111 行），但 compat 分支执行 `scripts/build_linux_compat.sh`，该脚本 `docker run -e` 只传 `JCODE_*` 和 `CARGO_*`，没有传 `RUSTC_WRAPPER`/`SCCACHE_*`/`ACTIONS_*`
- 容器内（manylinux2014，glibc 2.17）既没装 sccache 也没设 wrapper，整个编译走裸 rustc
- 宿主上的 sccache server 起起来是白点灯，零收益
- `RUSTC_WRAPPER=sccache` 只在"Build release binary"分支设置（179-181 行），而该分支被 `if: matrix.compat_container != true` 跳过（当前唯一启用的 target 是 compat_container: true）

### 2. 完整方案（改脚本，未实施）

1. 容器内装 sccache：用官方 Release 的 `x86_64-unknown-linux-musl` 静态二进制（manylinux glibc 2.17 跑 GNU 版可能起不来，musl 静态版保险）
2. `docker run -e` 追加透传：`ACTIONS_CACHE_URL`、`ACTIONS_RUNTIME_TOKEN`（runner 注入的 job 环境变量），容器内 `export RUSTC_WRAPPER=sccache SCCACHE_GHA_ENABLED=true`，构建前后 `sccache --start-server` / `--stop-server`
3. sccache 直接读写 GHA 缓存服务，跨 run 命中，无需宿主 chown（缓存实体不在容器磁盘上）

### 3. 不改脚本的替代方案（未实施）

给 `Setup sccache` 步骤加 `if: matrix.compat_container != true`，让 compat 腿完全跳过 sccache（不白装 server、不白跑 post 上传缓存），普通构建路径（将来启用 aarch64/macos 等时）保留 sccache 自动生效。

### 4. 建议

- 方案 1 的 target-dir + registry 缓存一旦生效恢复，增量编译收益已覆盖多数场景，单 leg（linux-x86_64 一腿）下 sccache 边际收益小
- sccache 的价值在多 matrix 腿共享缓存（当前 macos/aarch64 全注释了）、以及源码频繁变动时
- 代价：容器内装工具链耗时、token 透传进容器有暴露面（风险可控）、sccache 与 target 缓存并存时缓存体积翻倍

### 5. 当前决策

方案 1（缓存路径修复）已实施（`1378a4e78`），sccache 保持现状不动，待方案 1 缓存上量后确认增量收益再决定是否启用 sccache。
