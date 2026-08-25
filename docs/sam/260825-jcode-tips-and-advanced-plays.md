# 🔮 Jcode 使用技巧与高级玩法大全

> 整理日期：2026-08-25
> 资料来源：Jcode 源代码走查、64 份内置文档、GitHub README、jcode.sh 官网、国内知乎/CSDN/Text Matrix 技术博客、learnjcode.org 等外部资源综合整理。

---

## 一、📋 命令行与基本操作

| 场景 | 命令 | 说明 |
|---|---|---|
| 启动 TUI | `jcode` | 首次自动拉起后台 server 进程 |
| 单次非交互 | `jcode run "say hello"` | 跑完即退，适合脚本调用 |
| 脚本友好 | `jcode run --json` / `--ndjson` | JSON/NDJSON 结构化输出，wrapper 必备 |
| 后台常驻服务 | `jcode serve` + `jcode connect` | 多客户端连接同一 server |
| 按名称恢复会话 | `jcode --resume fox` | 用自然名恢复（动物名词+形容词组合） |
| 语音输入 | `jcode dictate` | 配合 STT 命令配置后使用 |
| 静默模式 | `jcode --quiet --no-update --no-selfdev ...` | wrapper/script 推荐组合 |
| 会话保存 | `/save [label]` / `/unsave` | 书签当前会话，后续可在 picker 中找到 |

**🚀 高级技巧**：Wrapper 场景建议总是用 `--quiet --no-update --no-selfdev` 三件套，消除无关噪音、避免更新检查和 repo 自动检测。

---

## 二、🧠 语义记忆系统（Memory）

Jcode 最核心的差异化功能之一。

### 工作原理
- 每次对话 turn 自动做 embedding 语义检索，相关记忆自动注入上下文，**Agent 无需消耗 token 主动调用检索工具**
- Memory SideAgent 在后台异步提取新记忆（触发条件：语义漂移、连续 K 轮未提取、会话结束）
- 两层记忆固化：**Sidecar 层**（每 turn，零延迟）+ **Ambient Garden 层**（后台深度整理）

### 记忆工具（Agent 侧）

```json
memory { action: "remember", content: "...", category: "fact|preference|correction",
         scope: "project|global", tags: ["tag1", "tag2"] }
memory { action: "recall" }              // 获取相关记忆
memory { action: "search", query: "..." } // 语义搜索
memory { action: "list", tag: "..." }    // 按标签列出
memory { action: "forget", id: "..." }   // 停用
memory { action: "link", from, to, relation }
memory { action: "tag", id, tags }
```

### 记忆类型与信任衰减

| 类型 | 半衰期 | 用途 |
|---|---|---|
| Correction | 365天 | 用户纠正行为（最高价值） |
| Preference | 90天 | 用户偏好 |
| Fact | 30天 | 代码库事实（易过期） |
| Procedure | 60天 | 操作步骤 |
| Inferred | 7天 | Agent 推断 |

### 💡 技巧
- **让 Agent 主动记住项目习惯**：比如「这个项目用 4 空格缩进」「部署命令是 make deploy」
- **记录负面记忆**：让 Agent 记住「不要用 println! 做生产日志」「.env 永不提交」
- **手动搜索历史**：`memory search "上次那个 auth refactor 的讨论"`
- **CLI 管理**：`jcode memory` 命令可查看/编辑/删除记忆

---

## 三、🐝 Swarm 多 Agent 协作

### 核心模式

| 模式 | 适用场景 | 特征 |
|---|---|---|
| **Light (fan-out)** | 5 个独立编辑并行 | 一层扇出、无递归、小团队(4-16)、轻量 |
| **Deep (comprehensive)** | 大型重构/探索性研究 | 递归自深、强制分解、critique gate、最多 1000 agent |

### Agent 生命周期
`spawned → ready → running → blocked → completed/failed/stopped/crashed`

### 通信方式
- **DM**（点对点）— 首选
- **Subtree broadcast**（仅发到自己 spawn 的子树）— 防止 1000 人风暴
- **Plan artifact dataflow**（DAG 边上的 typed 工件）— 主数据通道
- Topic channel / shared context — 已弱化，不建议用

### 💡 高级玩法
- **Agent 自主 spawn 子团队**：告诉 Agent "为这个大型重构 spawn 一个 swarm"，它会自动降级为 coordinator
- **Light 模式并行编辑**：让 Agent 同时修改 5 个无关联模块，冲突由系统自动通知
- **Deep 模式做探索**：「探索 scrollwm 多显示器支持」→ 自动生成 DAG 任务图，含 critique/verify gate，自动发现遗漏
- **子树广播**：coordinator 只对某个工作子树发指令，不影响其他
- **Completion report**：Agent 完成任务后自动向 owner 发送结构化报告（发现/变更/验证/blocker）

---

## 四、🌙 Ambient Mode（环境模式）

始终在线的后台 Agent，像大脑在睡眠中整理记忆。

### 启用方式

```toml
[ambient]
enabled = true
proactive_work = true           # 主动工作（默认 true）
pause_on_active_session = true  # 用户活跃时暂停
min_interval_minutes = 5
max_interval_minutes = 120
work_branch_prefix = "ambient/"
```

### 三大职能
1. **Garden**：记忆图整理（去重、矛盾解决、事实验证、过期剪枝）
2. **Scout**：分析最近会话和 git 历史，理解用户在做什么
3. **Work**：主动完成用户会感谢的任务（写测试、修小 bug、更新文档）

### 安全机制
- Tier 1 自动允许（读文件、跑测试、本地分支、记忆操作）
- Tier 2 需权限（发邮件、push、PR、部署、系统修改）
- 所有代码修改走 worktree + PR，永不直推 main

### 💡 高级玩法
- **用户反馈自动学习**：拒绝 ambient 的 PR → 自动生成记忆「用户不喜欢自动改测试」→ 下次不再做
- **Adaptive 调度**：自动根据用户 token 用量和 rate limit 调整运行频率
- **冷启动策略**：首次运行只做 garden，积累几个周期后才开始 proactive work
- **跨机器**：计划中，同一用户多台机器不冲突（leader election）

---

## 五、🔧 Self-Dev 自我开发模式

让 Agent 修改自己的源码、构建、热重载，全程无人工介入。

### 流程
1. 在 jcode 仓库内运行 `jcode`，自动检测并启用 self-dev 模式
2. 使用 `selfdev build` / `selfdev build-reload` 构建并热重载
3. Agent 修改代码 → 构建 → exec 新二进制 → 客户端自动重连 → 继续工作

### 💡 技巧
- **必须用前沿模型**（GPT-5.5 / Claude 最新版），弱模型容易产生隐蔽破坏
- `/reload` 命令让 server exec 进新二进制，所有客户端自动重连
- `--no-selfdev` 标志可关闭 self-dev 行为
- `scripts/dev_cargo.sh build --profile selfdev -p jcode` 比直接 cargo 快（sccache + lld）

### 推荐测试方式

```bash
cargo build --profile selfdev
./target/selfdev/jcode run --no-update --socket /run/user/1000/jcode-mytest.sock 'prompt'
```

避免影响正在运行的 shared server。

---

## 六、🎨 TUI 自定义与快捷键

### 对齐模式
- `Alt+C` 切换左右/居中对齐
- `/alignment` 命令
- config.toml 中配置

### 颜色系统（~22 个角色 + 222 个 rgb 字面量全部可配）

```
/colors                  # 列出所有角色
/colors <role> <#rrggbb> # 设置单个角色
/colors generate <seed>  # 从种子色自动推导和谐配色
/colors harmony          # 评分 + 具体修复建议
/colors export           # 导出为 TOML
/colors reset [role]     # 重置
```

### 关闭 emoji

```toml
[display]
emoji = false
```

或 `JCODE_NO_EMOJI=1` 启动。

### Shift+Enter
- 现代终端（kitty/G鬼ot/WezTerm/Alacritty/foot/iTerm2 3.5+/Warp/VS Code 1.109+）开箱即用
- 老终端用 `/terminal-setup` 自动配置
- 备用：`Alt+Enter` 或行尾反斜杠 + Enter

---

## 七、🔌 Provider 与多账号

### 支持 20+ Provider
`claude`, `openai`, `gemini`, `copilot`, `azure`, `openrouter`, `deepseek`, `fireworks`, `minimax`, `ollama`, `lmstudio` 等

### 脚本化无头登录（SSH 远程）

```bash
jcode login --provider openai --print-auth-url --json
jcode login --provider openai --callback-url 'http://localhost:1455/auth/callback?...'
```

### 本地端点 / vLLM

```bash
jcode provider add local-vllm \
  --base-url http://localhost:8000/v1 \
  --model Qwen/Qwen3-Coder-30B-A3B-Instruct \
  --no-api-key
```

### 💡 技巧
- **多账号切换**：`/account` 快速切换 OpenAI 账号（一个额度用完切另一个）
- **流式空闲超时**：`JCODE_STREAM_IDLE_TIMEOUT_SECS` 提高慢推理模型的超时
- **Extra body**：NVIDIA NIM DeepSeek 需要 `chat_template_kwargs`，通过 `extra_body` 注入
- **Cache 冷缓存警告**：Anthropic cache 5 分钟冷却，UI 会警告 cache miss

---

## 八、🌐 浏览器自动化

内置 `browser` 工具，基于 Firefox Agent Bridge。

### 操作
`status`, `setup`, `open`, `snapshot`, `get_content`, `interactables`, `click`, `type`, `fill_form`, `select`, `wait`, `screenshot`, `eval`, `scroll`, `upload`, `press`

### 快速设置

```bash
jcode browser status
jcode browser setup
```

### 💡 玩法
- Agent 直接操作网页做 E2E 测试
- 配合代码生成做完整的「写代码→部署→浏览器验证」流程
- 支持 JS eval、文件上传、表单填充

---


## 九、🌟 隐藏的高级玩法汇总

1. **让 Agent 用 Mermaid 画你项目的架构图到侧边栏** → 实时查看、自动更新
2. **配置 pre_tool hook 做安全审计** → 阻止所有危险 shell 命令
3. **用 light swarm 同时并行 5 个独立编辑** → 系统自动处理冲突
4. **用 deep swarm 做全面技术调研** → 自动分解、critique、gap 发现
5. **配置 ambient mode 做后台整理** → 用户不在时 Agent 自动写测试/修 bug/整理记忆
6. **用 `~/.jcode/prompt-overlay.md` 定制 Agent 行为** → 不改代码，全局生效
7. **用 `/colors generate` 一键生成和谐配色** → 告别手动调色
8. **跨 harness 恢复**：Claude Code 坏了？用 jcode resume 继续
9. **用 soft interrupt 在 Agent 工作中插话** → 不中断，自然融入
10. **用 `memory search` 跨会话回忆** → 像人类一样回忆过去讨论
11. **用 `jcode run --json` 集成到 CI/CD 脚本** → Agent 作为管道的一环
12. **用 spawn hook + 自定义脚本** → 每个 swarm agent 一个 tmux 窗格
13. **用 `--provider-profile` 脚本化切换模型端点** → 一套脚本多端点
14. **用 `/save` 书签会话** → 快速跳转到常用工作会话
15. **用 `memory link` 手动建立记忆关联** → 强化跨领域知识连接
---

## 十、更多

### 1. 🤖 Skills（技能系统）

#### 工作原理
- Skill 不在启动时全部加载，而是通过 embedding 语义匹配自动注入
- 用户也可用 `/skillname` slash 命令手动激活
- Agent 有 skill 工具可随时手动加载

#### 💡 技巧
- 当前可用：`/dispatching-parallel-agents`（多任务并行）、`/optimization`（性能优化）
- Skill 可被 prompt-overlay 覆盖或补充

---


### 2. 📄 System Prompt 配置

#### 多层叠加（按优先级）
1. 内置 base prompt（可被 `.jcode/system-prompt.md` 或 `~/.jcode/system-prompt.md` 替换）
2. Capability modules
3. Self-dev guidance
4. `./AGENTS.md` + `~/AGENTS.md`
5. `./.jcode/prompt-overlay.md` + `~/.jcode/prompt-overlay.md`（追加指导，最常用！）
6. `./.jcode/preferred-tools.md` + `~/.jcode/preferred-tools.md`
7. Memory + Skill prompt（动态注入）

#### 💡 技巧
- **最常用**：写 `~/.jcode/prompt-overlay.md` 全局追加指导，不碰 base prompt
- **项目特定**：在 repo 内写 `.jcode/prompt-overlay.md`
- **Swarm 独立**：`.jcode/swarm-prompt.md` 控制子 Agent 的路由行为，`/swarm-prompt` 编辑
- **修改内置 prompt 需 rebuild**（因为 `include_str!` 编译时嵌入）

---


### 3. 🛡️ Safety System

两档安全分级：
- **Tier 1 自动允许**：读文件、跑测试、本地分支、记忆操作
- **Tier 2 需权限**：发邮件、push、PR、部署、系统修改、密码操作

#### 自定义规则

```toml
[safety.rules]
allow_without_permission = ["create_pull_request"]   # 升级
require_permission = ["run_tests"]                     # 降级
allow_push_to = ["origin"]                             # 覆盖
```

#### 审批接口
- TUI 内置审批面板
- CLI：`jcode safety review/approve/deny/list/log`
- 邮件审批链接

---


### 4. ⚡ Soft Interrupt（软中断）

用户消息在 Agent 工作中以「软中断」方式注入，而非粗暴取消当前生成。

#### 注入点

| 点 | 时机 | 说明 |
|---|---|---|
| B | Turn 结束（无 tool） | 安全注入 |
| C | Tool 执行间（紧急） | 可跳过剩余工具 |
| D | 所有 tool 完成后 | **默认**，最安全 |

#### 操作
- 直接 Enter = 普通软中断（等待点 D 注入）
- Shift+Enter = 紧急软中断（可中断剩余工具执行）

---


### 5. 📡 生命周期 Hooks（外部集成）

在 `[hooks]` 配置外部命令，让其他程序观察/拦截 Agent 行为。

```toml
[hooks]
turn_end      = "~/bin/jcode-turn-notify"   # observer
session_start = ""
session_end   = ""
pre_tool      = "~/bin/jcode-tool-policy"   # gate（可拦截！）
post_tool     = ""
pre_tool_timeout_ms = 5000
```

#### 💡 高级玩法
- **`pre_tool` 策略拦截**：阻止 `rm -rf /`、阻止写入 `/etc/` 等危险操作
- **tmux 状态条 + 桌面通知**：每次 turn 结束时通知
- **JSON 事件日志**：将所有事件写入 `~/.local/state/jcode-events.jsonl` 供分析
- **环境变量覆盖**：`JCODE_HOOK_PRE_TOOL` 等 env 始终优于 config
- **递归保护**：`JCODE_HOOKS_DISABLED=1` 防止嵌套 jcode 调用触发 hooks

---


### 6. 🚪 Spawn Hook（终端路由）

控制 headed session 在哪个终端/multiplexer 中出现。

```toml
[terminal]
spawn_hook = "tmux new-window"
focus_hook = "~/bin/jcode-focus"
```

#### 环境元数据
`JCODE_SPAWN_KIND`, `JCODE_SPAWN_SESSION_ID`, `JCODE_SPAWN_TITLE`, `JCODE_SPAWN_CWD`, `JCODE_SPAWN_SWARM_ID`, `JCODE_SPAWN_COORDINATOR_SESSION_ID`

#### 💡 玩法
- **每个 swarm agent 一个 tmux 窗格**
- **自定义路由脚本**：根据 spawn kind 决定放 tmux/kitty/zellij
- **Wrapper 集成**：herd 类工具设置 `JCODE_SPAWN_HOOK` 环境，接管所有 spawn

---


### 7. 🔍 Agent Grep

Jcode 自研的 grep 工具，给 Agent 使用。

#### 优势
- 返回文件结构信息（函数列表、位移量等），Agent 不必读整文件即可推断
- 自适应截断：根据 Agent 已看过的内容动态缩减返回，节省上下文
- 支持 `find`/`outline`/`trace`/`grep` 四种模式

#### 💡 技巧
- `mode: "trace"` 追踪函数间的关系
- `mode: "outline"` 只看单个文件的结构
- 大文件先用 outline 看结构，再针对性 read 关键区域

---


### 8. 🔄 Resume / 跨 Harness 恢复

Jcode 支持从其他 coding agent 恢复会话！

#### 支持来源
Claude Code、Codex CLI、OpenCode、pi

#### 操作
- `/resume` 打开会话选择器
- `Enter` = 当前终端恢复
- `Ctrl+Enter` = 新终端打开
- `session_picker_enter` config 可交换两个绑定

---


### 9. 📊 终端色彩配置（高阶）

#### Harmony 评分系统（0-100）
五维评分：可读性、区分度、色相和谐、饱和度一致、色盲安全。所有计算在 Oklab 感知均匀空间进行。

#### 已知调色板评分（深色）

| 调色板 | 分数 |
|---|---|
| Dracula | 76 |
| Solarized Dark | 70 |
| Nord | 69 |
| Gruvbox Dark | 67 |

#### `/colors generate <seed>`
自动推导完整和谐调色板，包含 repair pass 修复冲突对。

---


### 10. 📐 Mermaid 渲染

- 侧边栏和聊天均可内联渲染 Mermaid 图表
- 自研 `mermaid-rs-renderer`，比浏览器渲染快 **1800x**，无 TS/browser 依赖
- 让 Agent 在侧边栏画架构图、状态图、流程图供你实时查看

---


### 11. 💻 环境变量速查（v0.80.0）

| 变量 | 用途 | 默认值 |
|---|---|---|
| `JCODE_HOME` | 指定 home 目录 | `~/.jcode` |
| `JCODE_NO_EMOJI=1` | 全局关闭 emoji | 不设置（emoji 启用） |
| `JCODE_TRACE` | 开启 tracing | 不设置（不开启） |
| `JCODE_STREAM_IDLE_TIMEOUT_SECS` | 流式空闲超时（秒） | `180` |
| `JCODE_OPENAI_EXTRA_BODY` | OpenAI 兼容端点额外请求体 | 不设置（无） |
| `JCODE_SPAWN_HOOK` | 终端 spawn 钩子 | 不设置（无） |
| `JCODE_FOCUS_HOOK` | 焦点钩子 | 不设置（无） |
| `JCODE_HOOK_PRE_TOOL` | pre_tool 钩子 | 不设置（无） |
| `JCODE_PERF_TIER` | 性能档位（full/reduced/minimal） | `auto`（自动检测） |
| `JCODE_GLYPH_SAFE_MODE` | 字体安全模式（on/off） | `auto`（自动检测） |
| `JCODE_NON_INTERACTIVE` | 非交互模式 | 不设置（交互模式） |
| `JCODE_SERVER_NAME` | 服务名 | `jcode` |
| `JCODE_DISABLE_POWER_INHIBIT` | 禁用电源抑制 | 不设置（电源抑制启用） |
| `JCODE_TRACK_CLIENT_CACHE` | 追踪客户端缓存 | 不设置（不追踪） |

---

## 附录

> 来源：`jcode --help` 实时拉取，版本 v0.80.0。

### 1. jcode命令/参数，汇总概要

#### 1.1 `jcode serve` — 启动后台 server daemon

| 参数 | 说明 |
|---|---|
| `-p, --provider <P>` | 初始 provider，默认 `auto` |
| `-m, --model <M>` | 指定模型 |
| `-C, --cwd <DIR>` | 本地客户端工作目录 |
| `--remote-working-dir <DIR>` | 远程 server 工作目录（配合 `--socket`） |
| `--server-name <NAME>` | server 稳定显示名 |
| `--socket <PATH>` | 自定义 socket 路径 |
| `--debug-socket` | 启用 debug socket |
| `--no-update` | 跳过更新检查 |
| `--auto-update` | 有新版时自动更新 |
| `--trace` | tool I/O 和 token 用量输出到 stderr |
| `--quiet` | 静默模式（wrapper 用） |
| `--resume [<ID>]` | 按 ID 恢复会话，无 ID 则列出会话 |
| `--no-selfdev` | 禁用 self-dev 自动检测 |
| `--provider-profile <NAME>` | 使用 config.toml `[[providers.<name>]]` 命名配置 |
| `--tool-profile <full\|minimal\|lite\|none>` | 工具暴露方案 |
| `--tools <LIST>` | 逗号分隔工具白名单，`*` 表示全部 |
| `--disabled-tools <LIST>` | 逗号分隔的禁用工具列表 |
| `--disable-base-tools` | 隐藏所有内置工具 |
| `--mcp-tools <auto\|eager\|deferred>` | MCP 工具暴露模式 |
| `--mcp-tools-token-threshold <N>` | auto 切 deferred 的 token 阈值 |

#### 1.2 `jcode server` — 管理后台 daemon

| 子命令 | 说明 |
|---|---|
| `start` | server 未运行时启动 |
| `promote` | 将共享 server 通道固定到指定版本 |
| `reload` | 优雅 reload 到最新二进制 |
| `stop` | 停止 server 并清除 socket |

参数与 `serve` 一致。

#### 1.3 `jcode connect` — 连接到运行中的 server

无独有参数，同 `serve`。

#### 1.4 `jcode run <MESSAGE>` — 执行单条消息后退出

| 参数 | 说明 |
|---|---|
| `<MESSAGE>` | **必选**：要发送的消息 |
| `--json` | 输出机器可读 JSON |
| `--ndjson` | 流式 NDJSON 事件 |

其余参数同 `serve`。

#### 1.5 `jcode session` — 会话管理

| 子命令 | 说明 |
|---|---|
| `rename` | 重命名已保存会话的显示名 |

参数同 `serve`。

#### 1.6 `jcode provider` — Provider 发现与选择

| 子命令 | 说明 |
|---|---|
| `list` | 列出可传给 `-p/--provider` 的 ID |
| `current` | 显示当前 provider 选择 |
| `add` | 添加 OpenAI-compatible 命名配置 |

参数同 `serve`。

#### 1.7 `jcode model` — 模型管理

| 子命令 | 说明 |
|---|---|
| `list` | 列出可传给 `-m/--model` 的模型名（支持 `--json`） |

参数同 `serve`。

#### 1.8 `jcode permissions` — Ambient 权限审批

无子命令，无独有参数。查看并响应 pending 的 ambient 权限请求。

---

#### 1.9 顶层共享 provider 完整列表（40+）

```
jcode, claude, anthropic-api, openai, openai-api, openrouter, bedrock,
azure, opencode, opencode-go, zai, kimi, ai302, baseten, cortecs,
comtegra, deepseek, fpt, firmware, hugging-face, moonshot-ai, nebius,
scaleway, stackit, groq, mistral, perplexity, together-ai, deepinfra,
fireworks, minimax, xai, grok-build, nvidia-nim, xiaomi-mimo,
meta-muse, celeris, lmstudio, ollama, chutes, cerebras,
alibaba-coding-plan, openai-compatible, cursor, copilot, gemini,
gemini-api, antigravity, google, auto
```

默认值：`auto`（自动检测）

---

### 2. 环境变量全览（v0.80.0）

> 来源：源码 `env_overrides.rs` + provider env + 运行时交叉验证。共 343 个 `JCODE_*` 变量，其中 ~160 个为 config.toml 的 env 覆盖映射。
>
> 标注：🖥️ = 服务端（`jcode serve` daemon）　💻 = 客户端（TUI/CLI）　🌐 = 双端通用

#### 2.1 TUI 界面与显示 💻

| 变量 | 作用 | 默认值 |
|---|---|---|
| 🔥 `JCODE_NO_EMOJI` | 关闭全局 emoji（`=1` 生效） | 不设置（emoji 启用） |
| 🔥 `JCODE_SHOW_THINKING` | 显示模型推理/思考过程 | `false` |
| `JCODE_REASONING_DISPLAY` | 推理内容展示方式（`hidden`/`inline`/`pinned`） | `hidden` |
| `JCODE_MARKDOWN_SPACING` | markdown 间距（`compact`/`document`） | `compact` |
| `JCODE_LATEX_RENDERING` | LaTeX 渲染（`none`/`unicode`/`image`） | `image` |
| 🔥 `JCODE_DIFF_MODE` | diff 显示（`off`/`inline`/`full-inline`/`pinned`/`file`） | `inline` |
| `JCODE_DIFF_LINE_WRAP` | diff 窗格自动换行 | `true` |
| `JCODE_DISPLAY_CENTERED` | 居中布局 | `false` |
| `JCODE_PIN_TODOS` | 固定 todo 侧边面板 | `false` |
| `JCODE_PIN_IMAGES` | 固定图片侧边面板 | `true` |
| `JCODE_IDLE_ANIMATION` | 空闲动画 | `false` |
| `JCODE_PROMPT_ENTRY_ANIMATION` | 用户提示行入场动画 | `true` |
| `JCODE_ANIMATION_FPS` | 动画帧率 (1–120) | `60` |
| `JCODE_REDRAW_FPS` | 活跃重绘帧率 (1–120) | `60` |
| `JCODE_DISABLED_ANIMATIONS` | 禁用特定动画（逗号分隔列表） | 不设置 |
| 🔥 `JCODE_PERFORMANCE` | 性能档位（`auto`/`full`/`reduced`/`minimal`） | `auto` |
| 🔥 `JCODE_PERF_TIER` | 性能档位（同 `JCODE_PERFORMANCE`，覆盖 config） | `auto` |
| `JCODE_GLYPH_SAFE_MODE` | 字体安全模式（`on`/`off`，macOS 终端用） | `auto`（自动检测） |
| `JCODE_CHAT_NATIVE_SCROLLBAR` | 聊天区原生滚动条 | `false` |
| `JCODE_SIDE_PANEL_NATIVE_SCROLLBAR` | 侧边栏原生滚动条 | `false` |
| `JCODE_SHOW_AGENTGREP_OUTPUT` | 显示 agentgrep 工具输出 | `false` |
| `JCODE_SHOW_BASH_OUTPUT` | 显示 bash 工具输出 | `false` |
| `JCODE_TOOL_CALL_DETAILS` | 工具调用详情（如 intent） | `false` |
| `JCODE_COMPACT_NOTIFICATIONS` | 紧凑通知样式 | `false` |
| `JCODE_COPY_BADGE_ALT_LABEL` | 复制徽标替代文本 | 不设置 |
| `JCODE_MESSAGE_TIMESTAMPS` | 显示消息时间戳 | `false` |
| `JCODE_QUEUE_MODE` | 队列模式（排队等待而非并发） | `false` |
| `JCODE_MOUSE_CAPTURE` | 鼠标捕获 | `true` |
| `JCODE_ACTIVE_SESSIONS_MANAGER` | 活跃会话管理器可见 | `false` |
| `JCODE_EXTERNAL_SESSIONS` | 显示外部会话源 | `true` |
| `JCODE_ITERM2_IMAGES` | iTerm2 内联图片渲染 | `true`（if supported） |
| `JCODE_WINDOW_TITLE` | 终端窗口标题 | `jcode` |

#### 2.2 快捷键覆盖 💻

> 覆盖 `[keybindings]` 配置项，修改无需重启。

| 变量 | 对应绑定 | 默认值 |
|---|---|---|
| `JCODE_SCROLL_UP_KEY` | 上滚 | `Ctrl+u` |
| `JCODE_SCROLL_DOWN_KEY` | 下滚 | `Ctrl+d` |
| `JCODE_SCROLL_PAGE_UP_KEY` | 上翻页 | `Ctrl+b` |
| `JCODE_SCROLL_PAGE_DOWN_KEY` | 下翻页 | `Ctrl+f` |
| `JCODE_SCROLL_PROMPT_UP_KEY` | 按 prompt 上滚 | 不设置 |
| `JCODE_SCROLL_PROMPT_DOWN_KEY` | 按 prompt 下滚 | 不设置 |
| `JCODE_SCROLL_BOOKMARK_KEY` | 书签滚动 | `Ctrl+g` |
| `JCODE_MODEL_SWITCH_KEY` | 下一个模型 | `Ctrl+m` |
| `JCODE_MODEL_SWITCH_PREV_KEY` | 上一个模型 | 不设置 |
| `JCODE_EFFORT_INCREASE_KEY` | 增加推理强度 | 不设置 |
| `JCODE_EFFORT_DECREASE_KEY` | 降低推理强度 | 不设置 |
| `JCODE_CENTERED_TOGGLE_KEY` | 居中切换 | `Ctrl+l` |
| `JCODE_WORKSPACE_LEFT_KEY` | 工作区左移 | `Ctrl+Left` |
| `JCODE_WORKSPACE_DOWN_KEY` | 工作区下移 | `Ctrl+Down` |
| `JCODE_WORKSPACE_UP_KEY` | 工作区上移 | `Ctrl+Up` |
| `JCODE_WORKSPACE_RIGHT_KEY` | 工作区右移 | `Ctrl+Right` |
| `JCODE_SIDE_PANEL_TOGGLE_KEY` | 侧边栏切换 | `Ctrl+o` |
| `JCODE_COPY_SELECTION_TOGGLE_KEY` | 复制选择模式 | `Ctrl+c` |
| `JCODE_DIAGRAM_PANE_TOGGLE_KEY` | 图表窗格切换 | `Ctrl+g` |
| `JCODE_DIFF_MODE_CYCLE_KEY` | 循环 diff 模式 | `Ctrl+Shift+d` |
| `JCODE_INFO_WIDGET_TOGGLE_KEY` | 信息部件切换 | `Ctrl+i` |
| `JCODE_NEW_TERMINAL_KEY` | 新终端 | `Ctrl+t` |
| `JCODE_DICTATION_COMMAND` | 语音输入命令 | 不设置 |
| `JCODE_DICTATION_MODE` | 语音输入模式 | 不设置 |
| `JCODE_DICTATION_KEY` | 语音输入快捷键 | 不设置 |
| `JCODE_DICTATION_TIMEOUT_SECS` | 语音输入超时（秒） | 不设置 |

#### 2.3 Provider 与模型 🖥️

**通用**

| 变量 | 作用 | 默认值 |
|---|---|---|
| 🔥 `JCODE_PROVIDER` | 指定 provider | `auto` |
| 🔥 `JCODE_MODEL` | 指定模型 | provider 默认 |
| `JCODE_NAMED_PROVIDER_PROFILE` | 命名 provider profile | 不设置 |
| 🔥 `JCODE_STREAM_IDLE_TIMEOUT_SECS` | 流式空闲超时（秒） | `180` |
| 🔥 `JCODE_MAX_RETRIES` | 最大重试次数 | `8` |
| `JCODE_RETRY_BACKOFF_CAP_SECS` | 重试退避上限（秒） | `30` |
| `JCODE_CROSS_PROVIDER_FAILOVER` | 跨 provider 故障转移 | `true` |
| `JCODE_SAME_PROVIDER_ACCOUNT_FAILOVER` | 同 provider 多账号故障转移 | `true` |
| `JCODE_OPENAI_REASONING_EFFORT` | OpenAI 推理强度 | provider 默认 |
| `JCODE_OPENAI_SERVICE_TIER` | OpenAI 服务等级 | `default` |
| `JCODE_OPENAI_TRANSPORT` | OpenAI 传输方式 | `ws` |
| 🔥 `JCODE_OPENAI_EXTRA_BODY` | 注入额外请求体（JSON 字符串） | 不设置 |
| `JCODE_PRESERVE_REASONING_CONTEXT` | 保留推理上下文 | `true` |
| `JCODE_CLAUDE_CLI_PATH` | Claude CLI 二进制路径 | `claude` |

**Claude/Anthropic**

| 变量 | 作用 | 默认值 |
|---|---|---|
| 🔥 `JCODE_ANTHROPIC_API_BASE` | 自定义 API 端点 | `https://api.anthropic.com` |
| `JCODE_ANTHROPIC_MODEL` | 模型覆盖 | provider 默认 |
| `JCODE_ANTHROPIC_MAX_TOKENS` | 最大 token 数 | provider 默认 |
| `JCODE_ANTHROPIC_REASONING_EFFORT` | 推理强度 | provider 默认 |
| `JCODE_ANTHROPIC_AUTH` | 认证 token | 不设置 |
| `JCODE_ANTHROPIC_AUTH_HEADER` | 自定义认证头 | 不设置 |
| `JCODE_ANTHROPIC_HEADERS` | 额外 HTTP 头 | 不设置 |
| 🔥 `ANTHROPIC_API_KEY` | API key（标准变量） | 不设置 |
| `ANTHROPIC_BASE_URL` | API 端点（标准变量） | 不设置 |

**OpenAI / OpenRouter**

| 变量 | 作用 | 默认值 |
|---|---|---|
| `JCODE_OPENAI_MODEL` | 模型覆盖 | provider 默认 |
| `JCODE_OPENAI_MAX_OUTPUT_TOKENS` | 最大输出 token | provider 默认 |
| `JCODE_OPENROUTER_API_BASE` | OpenRouter API 端点 | `https://openrouter.ai/api/v1` |
| `JCODE_OPENROUTER_MODEL` | OpenRouter 模型覆盖 | provider 默认 |
| `JCODE_OPENROUTER_MAX_TOKENS` | 最大 token | provider 默认 |
| 🔥 `OPENAI_API_KEY` | API key（标准变量） | 不设置 |
| `OPENAI_BASE_URL` | API 端点（标准变量） | 不设置 |
| `OPENROUTER_API_KEY` | OpenRouter key（标准变量） | 不设置 |

**其他 Provider**

| 变量 | 作用 | 默认值 |
|---|---|---|
| `JCODE_GEMINI_MODEL` | Gemini 模型覆盖 | provider 默认 |
| `JCODE_COPILOT_MODEL` | Copilot 模型覆盖 | provider 默认 |
| `JCODE_COPILOT_PREMIUM` | 强制 Copilot Premium 请求 | `false` |
| `JCODE_BEDROCK_MODEL` | Bedrock 模型覆盖 | provider 默认 |
| `JCODE_BEDROCK_REGION` | AWS 区域 | `us-east-1` |
| `JCODE_CURSOR_MODEL` | Cursor 模型覆盖 | provider 默认 |
| `JCODE_ANTIGRAVITY_MODEL` | Antigravity 模型覆盖 | provider 默认 |

#### 2.4 记忆 / 技能 / Swarm / Ambient 🖥️

| 变量 | 作用 | 默认值 |
|---|---|---|
| 🔥 `JCODE_MEMORY_ENABLED` | 启用语义记忆 | `true` |
| `JCODE_MEMORY_MODEL` | 记忆处理模型 | 跟随主模型 |
| `JCODE_MEMORY_SIDECAR_ENABLED` | 记忆 sidecar 进程 | `false` |
| `JCODE_PERSIST_MEMORY_INJECTIONS` | 持久化记忆注入 | `true` |
| `JCODE_ENABLE_MERMAID` | Mermaid 图表渲染 | `true` |
| 🔥 `JCODE_SWARM_ENABLED` | 启用 Swarm 多 agent | `true` |
| `JCODE_SWARM_MODEL` | Swarm agent 默认模型 | 跟随主模型 |
| 🔥 `JCODE_SWARM_MAX_CONCURRENT_AGENTS` | 最大并发 agent 数 | `8` |
| `JCODE_SWARM_SPAWN_MODE` | spawn 模式（`visible`/`headless`/`inline`） | `inline` |
| `JCODE_AMBIENT_ENABLED` | 启用 Ambient 后台模式 | `false` |
| `JCODE_AMBIENT_PROVIDER` | Ambient provider | 不设置 |
| `JCODE_AMBIENT_MODEL` | Ambient 模型 | 不设置 |
| `JCODE_AMBIENT_MIN_INTERVAL` | 最小检查间隔（秒） | `300` |
| `JCODE_AMBIENT_MAX_INTERVAL` | 最大检查间隔（秒） | `3600` |
| `JCODE_AMBIENT_PROACTIVE` | 主动模式 | `false` |
| `JCODE_AUTO_POKE` | 自动 poke 会话 | `false` |
| `JCODE_AUTOJUDGE_ENABLED` | 自动审批 | `false` |
| `JCODE_AUTOREVIEW_ENABLED` | 自动 review | `false` |

#### 2.5 Hooks / 通知 / 集成 🌐

| 变量 | 作用 | 默认值 |
|---|---|---|
| `JCODE_HOOK_TURN_START` | Turn 开始钩子 | 不设置 |
| `JCODE_HOOK_TURN_END` | Turn 结束钩子 | 不设置 |
| `JCODE_HOOK_SESSION_START` | 会话开始钩子 | 不设置 |
| `JCODE_HOOK_SESSION_END` | 会话结束钩子 | 不设置 |
| 🔥 `JCODE_HOOK_PRE_TOOL` | 工具执行前钩子（可拦截） | 不设置 |
| `JCODE_HOOK_POST_TOOL` | 工具执行后钩子 | 不设置 |
| `JCODE_HOOK_PRE_TOOL_TIMEOUT_MS` | pre_tool 超时（毫秒） | `5000` |
| `JCODE_HOOKS_DISABLED` | 禁用 hooks（递归保护） | 不设置 |
| 🔥 `JCODE_SPAWN_HOOK` | 终端 spawn 钩子命令 | 不设置 |
| 🔥 `JCODE_FOCUS_HOOK` | 焦点切换钩子命令 | 不设置 |
| `JCODE_SPAWN_KIND` | spawn 类型（元数据，只读） | 自动设置 |
| `JCODE_SPAWN_SESSION_ID` | spawn 会话 ID（元数据） | 自动设置 |
| `JCODE_SPAWN_TITLE` | spawn 标题（元数据） | 自动设置 |
| `JCODE_SPAWN_CWD` | spawn 工作目录（元数据） | 自动设置 |
| 🔥 `JCODE_TELEGRAM_BOT_TOKEN` | Telegram bot token | 不设置 |
| 🔥 `JCODE_TELEGRAM_CHAT_ID` | Telegram chat ID | 不设置 |
| `JCODE_TELEGRAM_REPLY_ENABLED` | Telegram 回复功能 | `false` |
| `JCODE_DISCORD_BOT_TOKEN` | Discord bot token | 不设置 |
| `JCODE_DISCORD_CHANNEL_ID` | Discord 频道 ID | 不设置 |
| `JCODE_DISCORD_REPLY_ENABLED` | Discord 回复功能 | `false` |
| `JCODE_NTFY_SERVER` | ntfy 服务器地址 | 不设置 |
| `JCODE_NTFY_TOPIC` | ntfy 主题 | 不设置 |
| `JCODE_EMAIL_TO` | 邮件通知收件人 | 不设置 |
| `JCODE_EMAIL_REPLY_ENABLED` | 邮件回复功能 | `false` |
| `JCODE_GATEWAY_ENABLED` | API Gateway | `false` |
| `JCODE_GATEWAY_PORT` | API Gateway 端口 | `4000` |
| `JCODE_GATEWAY_BIND_ADDR` | API Gateway 绑定地址 | `127.0.0.1` |
| `JCODE_PREVENT_SLEEP_WHILE_STREAMING` | 流式时防止系统休眠 | `true` |
| `JCODE_DISABLE_POWER_INHIBIT` | 禁用电源抑制 | 不设置（启用） |

#### 2.6 工具 / 浏览器 / Web 🖥️

| 变量 | 作用 | 默认值 |
|---|---|---|
| `JCODE_TOOL_PROFILE` | 工具 profile（`full`/`acp`/`minimal`/`none`） | `full` |
| `JCODE_TOOLS` | 启用的工具列表 | 全部 |
| `JCODE_DISABLED_TOOLS` | 禁用的工具列表 | 不设置 |
| `JCODE_DISABLE_BASE_TOOLS` | 禁用内置工具集 | `false` |
| `JCODE_MCP_TOOLS` | MCP 工具模式 | `auto` |
| `JCODE_MCP_TOOLS_TOKEN_THRESHOLD` | MCP 工具 token 阈值 | 不设置 |
| 🔥 `JCODE_WEBSEARCH_ENGINE` | 搜索引擎（`duckduckgo`/`bing`/`searxng`） | `duckduckgo` |
| `JCODE_BING_API_KEY` | Bing API key | 不设置 |
| `JCODE_BING_MARKET` | Bing 市场（如 `en-US`） | `en-US` |
| `JCODE_SEARXNG_URL` | SearXNG 实例 URL | 不设置 |
| `JCODE_LATEX_COMMAND` | latex 命令路径 | `latex` |
| `JCODE_DVIPNG_COMMAND` | dvipng 命令路径 | `dvipng` |
| `BROWSER` | 浏览器打开命令 | 系统默认 |

#### 2.7 运行时 / 路径 / Server 🌐

| 变量 | 作用 | 默认值 |
|---|---|---|
| 🔥 `JCODE_HOME` | jcode 数据目录 | `~/.jcode` |
| 🔥 `JCODE_RUNTIME_DIR` | 运行时 socket 目录 | `$XDG_RUNTIME_DIR` |
| `JCODE_SCRATCH_DIR` | 临时文件目录 | 系统临时目录 |
| 🔥 `JCODE_SOCKET` | 自定义 Unix socket 路径 | `$JCODE_RUNTIME_DIR/jcode.sock` |
| 🔥 `JCODE_SERVER_NAME` | server daemon 名称 | `jcode` |
| `JCODE_SERVER_DISPLAY_NAME` | server 显示名称 | `jcode` |
| `JCODE_TEMP_SERVER` | 临时 server 模式 | `false` |
| `JCODE_SERVER_SCOPE` | server 作用域 | 不设置 |
| 🔥 `JCODE_CHECK_UPDATES` | 检查更新 | `true` |
| 🔥 `JCODE_UPDATE_CHANNEL` | 更新通道（`stable`/`canary`） | `stable` |
| `JCODE_NO_AUTO_UPDATE` | 禁用自动更新 | `false` |
| `JCODE_AUTO_SERVER_RELOAD` | 自动重载 server | `true` |
| `JCODE_NO_TELEMETRY` | 禁用遥测 | `false` |
| `JCODE_ALLOW_SERVER_VERSION_MISMATCH` | 允许 server 版本不匹配 | `false` |

#### 2.8 调试 / 测试 / 开发 🌐

| 变量 | 作用 | 默认值 |
|---|---|---|
| 🔥 `JCODE_TRACE` | 输出 tool I/O 与 token 到 stderr | 不设置 |
| 🔥 `JCODE_NON_INTERACTIVE` | 非交互模式（CI/脚本） | 不设置 |
| `JCODE_QUIET` | 静默模式 | 不设置 |
| `JCODE_CI` | CI 环境标记 | 不设置 |
| `JCODE_NO_COLOR` | 禁用颜色输出 | 不设置 |
| 🔥 `JCODE_DEBUG_SOCKET` | 启用 debug socket | `false` |
| `JCODE_LOG_JSON` | JSON 格式日志 | `false` |
| `JCODE_LOG_SERVED_MODEL` | 记录实际使用的模型名 | `false` |
| `JCODE_TRACK_CLIENT_CACHE` | 追踪客户端缓存 | `false` |
| 🧊 `JCODE_LOG_MARK` | 日志标记 | 不设置 |
| 🧊 `JCODE_LOG_MODEL_PICKER_TIMING` | 模型选择器耗时日志 | 不设置 |
| 🧊 `JCODE_LOG_SERVICE_TIER` | 服务等级日志 | 不设置 |
| 🧊 `JCODE_DEBUG_CONTROL` | debug socket 控制路径 | 不设置 |
| 🧊 `JCODE_DEBUG_CMD_PATH` | debug 命令路径 | 不设置 |
| 🧊 `JCODE_DEBUG_RESPONSE_PATH` | debug 响应路径 | 不设置 |
| 🧊 `JCODE_DEBUG_MESSAGE_TIMEOUT_SECS` | debug 消息超时（秒） | 不设置 |
| 🧊 `JCODE_TUI_SCROLL_TRACE` | TUI 滚动追踪 | 不设置 |
| 🧊 `JCODE_TUI_SLOW_FRAME_MS` | TUI 慢帧阈值（毫秒） | 不设置 |
| 🧊 `JCODE_TUI_FLICKER_DETECTION` | TUI 闪烁检测 | 不设置 |
| 🧊 `JCODE_LOGIN_QR` | 登录 QR 码 | 不设置 |
| 🧊 `JCODE_SHOW_LOGIN_QR` | 显示登录 QR | 不设置 |
| 🧊 `JCODE_SHOW_TUI_LOGIN_QR` | TUI 显示登录 QR | 不设置 |
| 🧊 `JCODE_TUI_LOGIN_QR` | TUI 登录 QR | 不设置 |
| 🧊 `JCODE_TEST_*` | 测试标记（通配） | 不设置 |
| 🧊 `JCODE_LIVE_*` | 线上测试标记（通配） | 不设置 |
| 🧊 `JCODE_MD_FUZZ_*` | Markdown 模糊测试（通配） | 不设置 |
| 🧊 `JCODE_E2E_BIN` | E2E 测试二进制路径 | 不设置 |
| 🧊 `JCODE_CHECKPOINT` | 检查点标记 | 不设置 |
| 🧊 `JCODE_AUTH_FIXTURE_DIR` | 认证夹具目录 | 不设置 |
| 🧊 `JCODE_AUTH_TIMING` | 认证耗时记录 | 不设置 |
| 🧊 `JCODE_DISCOVERY_BENCHMARK` | 发现基准测试 | 不设置 |
| 🧊 `JCODE_LIVE_TEST_*` | 线上测试（通配） | 不设置 |
| 🧊 `JCODE_SCHEMA_QUIRKS_PATH` | Schema 兼容路径 | 不设置 |
| 🧊 `JCODE_CLIENT_RUNTIME_MEMORY_LOG*` | 客户端运行时内存日志 | 不设置 |
| 🧊 `JCODE_RUNTIME_MEMORY_LOG*` | 服务端运行时内存日志 | 不设置 |

#### 2.9 第三方兼容变量（非 JCODE_）

`ANTHROPIC_API_KEY`、`ANTHROPIC_AUTH_TOKEN`、`ANTHROPIC_BASE_URL`、`OPENAI_API_KEY`、`OPENAI_BASE_URL`、`OPENROUTER_API_KEY`、`AWS_ACCESS_KEY_ID`、`AWS_SECRET_ACCESS_KEY`、`AWS_REGION`、`AWS_PROFILE`、`GITHUB_TOKEN`/`GH_TOKEN`、`GOOGLE_CLOUD_PROJECT`、`XDG_CONFIG_HOME`、`XDG_DATA_HOME`、`XDG_RUNTIME_DIR`、`SSH_CONNECTION`、`SSH_TTY`、`TMUX`、`TMUX_PANE`、`ZELLIJ_SESSION_NAME`、`KITTY_WINDOW_ID`、`WEZTERM_PANE`、`TERM_PROGRAM`、`WAYLAND_DISPLAY`、`NO_COLOR`、`COLORTERM` 等。
