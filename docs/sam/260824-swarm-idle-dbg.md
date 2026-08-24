# Swarm Idle Worker Reaper 调试记录

> 记录日期：2026-08-24

## 一、问题与日志证据

### 1. 问题

设置 `JCODE_SWARM_IDLE_WORKER_REAP_SECS=0` 后，worker 仍在约 30 分钟后被回收。

### 2. 日志证据

```
[2026-08-24 21:58:52.873] Reaped idle spawned swarm worker session_dog (idle > 1800s)
[2026-08-24 21:58:52.873] Reaped idle spawned swarm worker session_cricket (idle > 1800s)
[2026-08-24 22:18:54.472] Reaped idle spawned swarm worker session_jaguar (idle > 1800s)
[2026-08-24 22:34:52.907] Reaped idle spawned swarm worker session_lizard (idle > 1800s)
```

所有回收日志均显示 `idle > 1800s`（1800 秒 = 30 分钟），用的是默认值，不是设置的 0。

## 二、根因分析

### 1. Self-dev 触发条件

TUI 启动时，`resolve_subscribe_metadata`（`crates/jcode-tui/src/tui/mod.rs:1544-1566`）会**从当前工作目录向上遍历**，逐级检查 `is_jcode_repo`：

```rust
let mut current = Some(dir);
while let Some(path) = current {
    if crate::build::is_jcode_repo(path) {
        selfdev = true;
        break;
    }
    current = path.parent();
}
```

`is_jcode_repo`（`crates/jcode-build-support/src/paths.rs:642`）的判断条件：
1. 目录下有 `Cargo.toml`，且内容包含 `name = "jcode"`
2. 目录下有 `.git` 文件或目录

### 2. 问题流程

1. 用户在 `/fk-jcode` 目录下启动 `jcode` → TUI 自动进入 self-dev 模式
2. Self-dev 模式下 TUI 连接 daemon 时，如果 daemon 没跑，**自动启动它**
3. 这个自动启动的 daemon 进程**不继承用户 shell 的环境变量**
4. 用户 `export JCODE_SWARM_IDLE_WORKER_REAP_SECS=0` 只在 shell 中生效，daemon 读不到
5. 用户手动 `JCODE_SWARM_IDLE_WORKER_REAP_SECS=0 jcode serve` 时，daemon 已经跑着了，命令只是连接上去

### 3. 服务器启动日志

```
[2026-08-24 21:28:12.384] [srv:workshop] Server 🔨 workshop starting
[2026-08-24 21:43:52.872] [srv:camp] Server ⛺ camp starting
[2026-08-24 21:43:52.872] [srv:camp] Debug control enabled; idle timeout monitor disabled.
```

服务器启动时没有 `Temporary server lifecycle enabled` 行，说明 env var 不在进程环境里。

## 三、环境变量生效确认（2026-08-24 23:35 追加）

### 1. 验证方法

通过 `/proc/<pid>/environ` 直接查看 server 进程的环境变量，确认 `JCODE_SWARM_IDLE_WORKER_REAP_SECS=0` 是否已传递到进程。

### 2. 验证结果

手动关 serve，确认 `jcode --no-selfdev` 没有另跑一套了：前者关停，后者提示离线重连中，前者启，后者连接成功。

两个 server 进程的环境变量：

```
PID 1083880:
  JCODE_SWARM_IDLE_WORKER_REAP_SECS=0 ✅
  JCODE_SWARM_TERMINAL_MEMBER_RETENTION_SECS=86400 ✅

PID 1085698:
  JCODE_SWARM_IDLE_WORKER_REAP_SECS=0 ✅
```

**结论：环境变量已生效。** reaper 已被禁用，之后跑 swarm 任务不会再有 30 分钟自动回收。

## 四、正确做法

### 1. 禁用 self-dev 模式

```bash
jcode --no-selfdev
```

每次启动时加 `--no-selfdev` 参数，TUI 不会自动检测 jcode 仓库目录。

### 2. 确保 env var 生效

```bash
# 1. 先停 daemon
jcode server stop

# 2. 同一行命令设 env 启动（确保传进子进程）
JCODE_SWARM_IDLE_WORKER_REAP_SECS=0 JCODE_DEBUG_CONTROL=1 jcode serve

# 3. 然后启动 TUI 连接它（用 --no-selfdev 避免自动拉新 server）
jcode --no-selfdev
```

## 五、完整回收机制回顾

Worker 被回收由 **5 个维度、至少 7 条路径**共同决定，`JCODE_SWARM_IDLE_WORKER_REAP_SECS` 只能控制其中一条：

| # | 路径 | 可控？ |
|---|------|--------|
| A1 | Idle worker reaper（默认 30min） | ✅ `JCODE_SWARM_IDLE_WORKER_REAP_SECS` |
| A2 | Terminal 成员 GC（默认 24h） | ✅ `JCODE_SWARM_TERMINAL_MEMBER_RETENTION_SECS` |
| B1 | 客户端断开清理（立即） | ❌ 不受控 |
| C1 | run_plan 结束清理 | ✅ `retain_agents` 参数 |
| C2 | run_plan 中途容量恢复（达上限时） | ⚠️ 受 `swarm_max_concurrent_agents` 影响 |
| D1 | 临时服务器 idle 超时（默认 30min） | ⚠️ 仅手动 `JCODE_TEMP_SERVER=1` 启用，dead code |
| E1 | 广播保留 15min（感知层假象） | ❌ 无法配置，仅显示层 |

## 六、环境变量读取位置

`crates/jcode-app-core/src/server/swarm.rs:257-271`:

```rust
const DEFAULT_SWARM_IDLE_WORKER_REAP_SECS: u64 = 30 * 60;

pub(super) fn swarm_idle_worker_reap_after() -> Option<Duration> {
    let secs = std::env::var("JCODE_SWARM_IDLE_WORKER_REAP_SECS")
        .ok()
        .and_then(|value| value.trim().parse::<u64>().ok())
        .unwrap_or(DEFAULT_SWARM_IDLE_WORKER_REAP_SECS);
    (secs > 0).then(|| Duration::from_secs(secs))
}
```

`std::env::var` 读取的是 **daemon 进程**的环境，不是 TUI 客户端的 shell。每次 GC tick 都会重新读取，所以只要 daemon 进程环境里有变量就生效。

## 七、验证方法（2026-08-24 23:27 追加）

### 1. 环境变量生效测试

```bash
# 1. 手动启动 serve（带 env var）
JCODE_SWARM_IDLE_WORKER_REAP_SECS=0 JCODE_SWARM_TERMINAL_MEMBER_RETENTION_SECS=86400 jcode serve --trace 2>&1 | tee /tmp/jcode-serve.log

# 2. 另开终端，用 --no-selfdev 启动 TUI（避免自动拉新 server）
jcode --no-selfdev

# 3. 跑一个 swarm 任务
# 4. 观察半小时后日志
tail -f ~/.jcode/logs/jcode-$(date +%Y-%m-%d).log
```

### 2. 验证要点

| 观察项 | 预期 |
|--------|------|
| 30 分钟后是否有 `Reaped idle spawned swarm worker (idle > 1800s)` | 若没有 → env var 生效 ✅ |
| 服务器日志中是否有 `Temporary server lifecycle enabled` 行 | 若有 → 临时服务器模式，需注意 idle 超时 |
| `jcode serve` 关闭后 TUI 是否显示"离线重连中" | 是 → 正确，TUI 没有自动拉新 server |
| `jcode serve` 重启后 TUI 是否自动连接成功 | 是 → `--no-selfdev` 生效，TUI 只连接不启动 |

### 3. 日志关键行含义

| 日志行 | 含义 |
|--------|------|
| `Reaped idle spawned swarm worker (idle > 1800s)` | 用默认 30min 回收，**env var 未生效** |
| `Debug control enabled; idle timeout monitor disabled.` | **self-dev 自动启动**的服务器（带 debug socket） |
| `No clients connected. Server will exit after N minutes of idle.` | 临时服务器，N 分钟后无客户端自动关闭 |
| `Server listening on "/tmp/jcode-1000/jcode.sock"` | 服务器已就绪 |

---

### 4. 验证确认

> 手动关 serve，确认 `jcode --no-selfdev` 没有另跑一套了：前者关停，后者提示离线重连中，前者启，后者连接成功。

---
### 5. 日志验证结果 （2026-08-24 23:48 追加）

从 `meadow` 服务器启动（23:07:18）至今，日志中**没有** `Reaped idle spawned swarm worker` 事件：

```
# 最后一次 reaper 事件在 22:34:52（旧服务器）
22:34:52 Reaped idle spawned swarm worker lizard (idle > 1800s)

# 23:07:18 meadow 新服务器启动后，至今无 reaper 事件
```

新服务器启动后，日志中出现的 `SWARM_LIFECYCLE member_remove_start` 是会话正常清理，不是 reaper 行为。

**结论**：结合 `/proc/<pid>/environ` 确认 `JCODE_SWARM_IDLE_WORKER_REAP_SECS=0` 已传入进程，环境变量确认生效，reaper 已被禁用。

---

## 八、swarm 下发命令溯源（2026-08-25 00:00 追加）

### 1. 查找目标

找到用户测试时下发"swarm 生成 2 个 worker"的**语言命令原文**及对应工具调用。

### 2. 查找思路与步骤

1. **从服务器日志定位 worker 会话**：grep `Reaped idle spawned swarm worker` 找到被回收的 worker 会话名（dog/cricket/jaguar/lizard 等）
2. **从 worker 会话反推 spawn 时间**：`jaguar`（22:18 回收）、`lizard`（22:34 回收）都是 `idle > 1800s` 被回收，说明它们的 `last_status_change` 约在 21:46-21:48
3. **在日志中按时间窗口搜索 swarm 工具调用**：grep `resolved_tool_name=swarm`，找到 21:46:16 和 21:46:25 两次 swarm 调用，均来自 `session_snake`（coordinator），工作目录 `/issue-agents`
4. **确认 coordinator 会话文件**：`~/.jcode/sessions/session_snake_*.json`
5. **从会话文件中提取 user 角色消息**：遍历 JSON 找 `role == "user"` 的消息，拿到用户语言命令原文
6. **从会话文件中提取 swarm 工具调用**：找 `name == "swarm"` 的 tool_use 消息，拿到模型生成的 JSON 参数（label/prompt/action）

### 3. 找到的信息明细

**用户语言命令原文**：

```text
用 swarm spawn 2 个代理： 
- label 'api reviewer', prompt '审查 src/api.rs 的公开接口' 
- label 'test writer', prompt '为 src/api.rs 补充单元测试' 
 然后 await_members 等全部完成

实际执行它，就直接跑，我在测试swarm功能。retain_agents=true  保留完成后的工作者
```

**模型生成的 swarm 工具调用**（21:46，来自 session_snake）：

```json
{"action": "spawn", "label": "api reviewer", "prompt": "审查 src/api.rs 的公开接口"}
{"action": "spawn", "label": "test writer", "prompt": "为 src/api.rs 补充单元测试"}
{"action": "await_members", "mode": "all"}
```

**对应关系**：

| 时间 | 事件 | 说明 |
|------|------|------|
| 21:46:16 | `swarm spawn` (93ms) | 生成 api reviewer → session_jaguar |
| 21:46:25 | `swarm spawn` (1645ms) | 生成 test writer → session_lizard |
| 22:18:54 | `Reaped jaguar (idle > 1800s)` | 30 分钟后被 idle reaper 回收 |
| 22:34:52 | `Reaped lizard (idle > 1800s)` | 30 分钟后被 idle reaper 回收 |

### 4. 关键结论

- 语言命令原文保存在 coordinator 会话文件（`session_snake_*.json`）的 user 消息里，可以完整找回
- 日志中 swarm 工具调用的 input 被 redacted（`input_keys=<redacted>`），但工具名称/时间/session 可查
- 模型生成的工具调用 JSON 也在会话文件里，未脱敏，可验证 `retain_agents` 等参数是否真的传了

### 5. 用途

- 复现问题：直接用语言命令原文重跑，配合新 server 观察是否还会被回收
- 验证参数：确认模型是否真的把 `retain_agents=true` 传给了 `run_plan`/`await_members`（从会话 JSON 看，实际只有 `await_members` 带 `retain_agents: true`，spawn 两次都没带——这是"保留失败"的一个疑点）

---

## 九、echo worker 触发测试与广播逻辑确认（2026-08-25 00:25 追加）

### 1. 测试触发命令

用户原命令简化版（worker 任务改为 echo，快速完成）：

```text
用 swarm spawn 2 个代理：
- label 'echoer-1', prompt '在 /_ext/home/headless/xm-zs01/fk-jcode 下执行命令 echo 123，直接输出结果并完成'
- label 'echoer-2', prompt '在 /_ext/home/headless/xm-zs01/fk-jcode 下执行命令 echo 456，直接输出结果并完成'
然后 await_members mode="all"
```

实际触发（2026-08-24 16:07）：

```json
{"action": "spawn", "label": "echoer-1", "prompt": "... echo 123 ..."}
{"action": "spawn", "label": "echoer-2", "prompt": "... echo 456 ..."}
{"action": "await_members", "mode": "all"}
```

生成的 worker 会话：

| worker | session_id | 任务 |
|--------|-----------|------|
| blossom | `session_blossom_1787587660136_b3df2e40db83ce77` | echo 123 |
| daisy | `session_daisy_1787587660214_f6bc287b4edfe037` | echo 456 |

### 2. 测试结果

```
🐝 Swarm await finished
All members done. All 2 members are done: blossom, daisy
  ✓ blossom (failed)
  ✓ daisy (failed)

失败原因：OpenAI-compatible chat request failed
  endpoint: http://localhost:8090/v1/chat/completions
  model: st/deepseek-v4-flash
```

**worker 未执行 echo 就在模型路由层失败**（模型路由问题，与 issue #512/#981 同源）。

### 3. 观察计划

| 时间点 | 观察项 |
|--------|--------|
| 16:22 左右（15min） | 面板（底部 + Alt+N）中 failed worker 应消失（E1 广播保留结束） |
| 16:45-17:15（30-60min） | `swarm list` 确认成员是否仍在；日志确认无 `Reaped` 事件 |

### 4. 广播逻辑明细（代码确认）

**广播（SwarmStatus）共三层：**

```
server 成员表 (swarm_members HashMap)     ← 完整成员，24h 保留
  ↓ broadcast_swarm_status_now 过滤
     member_in_status_broadcast(m, retention)
     = live 成员 或 terminal 且 last_status_change < 15min
  ↓ 只发符合条件的成员
TUI remote_swarm_members                  ← 收到后整体覆盖
  ↓ inline_swarm_members() 过滤子树
     filter_inline_swarm_subtree(成员, self_id)
Alt+N 面板 / 底部显示项
```

**关键代码：**

`crates/jcode-app-core/src/server/swarm.rs`（server 广播过滤）：

```rust
let members_list = session_ids.iter().filter_map(|sid| {
    members_guard.get(sid)
        .filter(|m| member_in_status_broadcast(m, broadcast_terminal_retention))
        .map(|m| SwarmMemberStatus { ... })
});

pub(super) fn member_in_status_broadcast(member, retention) -> bool {
    !member_status_is_terminal(&member.status)
        || member.last_status_change.elapsed() < retention
}
```

`crates/jcode-tui/src/tui/app/remote/server_events.rs`（TUI 收到后整体覆盖）：

```rust
ServerEvent::SwarmStatus { members } => {
    app.remote_swarm_members = members;   // ← 整体覆盖，旧成员消失
}
```

`crates/jcode-tui/src/tui/app/tui_state.rs`（Alt+N 面板取数）：

```rust
fn inline_swarm_members(&self) -> Vec<SwarmMemberStatus> {
    ...
    filter_inline_swarm_subtree(&self.remote_swarm_members, self_id)
}
```

**关键结论：**

1. **Alt+N 面板与底部显示项同源**（都是 `remote_swarm_members`），15min 后 terminal worker 从广播剔除，**Alt+N 也看不到**
2. 广播保留判断是**绝对时间**（`last_status_change.elapsed() < 15min`），重新广播（如 spawn 新 worker）**不会带回** 15 分钟前的 terminal 成员
3. 唯一能重新看到的方式：该成员的 `last_status_change` 被刷新（如 `wake`/`resume`/`retry` 把 terminal 状态拉回 live）
4. 成员记录本身仍在 server（24h `JCODE_SWARM_TERMINAL_MEMBER_RETENTION_SECS` 保留），可通过 `swarm list/status` 查询

---

### 5. 观察验证：46 分钟后 worker 仍在 （2026-08-25 00:57 追加）

`echo` 测试的两个 worker（blossom/daisy，failed 状态）在 **46 分钟后**：

| 观察项 | 结果 |
|--------|------|
| `swarm list` 查询 | ✅ 成员仍在 server（46min > 默认 30min 回收线） |
| Alt+N / 底部显示 | ❌ 看不到（广播保留 15min 已剔除，属于 E1 显示层行为） |
| idle reaper 是否回收 | ✅ **没有**——若 env 未生效，30min 时应有 `Reaped (idle > 1800s)` 日志，46min 无回收 |

**结论链完整**：`JCODE_SWARM_IDLE_WORKER_REAP_SECS=0` 生效 → reaper 禁用 → failed worker 46 分钟仍保留。Alt+N 看不到纯粹是广播保留（15min）的显示层行为，成员实际还在（24h 保留期内可查）。

---

### 6. 底部显示类型全景 （2026-08-25 01:10 追加）

按代码顺序（`crates/jcode-tui/src/tui/ui.rs` 的 fixed_height 组成），status bar 上方可出现的条带/区域：

| 类型 | 触发条件 | 说明 | 控制 |
|------|---------|------|------|
| **Queued messages**（排队消息） | 有待发送/被 interrupt 的 prompt | 显示待发消息条数（最多 3 行） | `queue_mode` 配置 |
| **Swarm strip**（现有的） | `inline_swarm_gallery_active()` 且面板聚焦/未 stand down | agent 条带 | `Alt+N`，跟随成员存在 |
| **Notification line** | `app.has_notification()` | 一次性系统通知（如 "Swarm view closed"） | 自动消失，无开关 |
| **Idle donut** | 空闲动画 | 启动/空闲转圈 | `[display] idle_animation` / `disabled_animations` |
| **Overscroll status** | 滚动超过底部 | 弹性底部状态行 | `[display] overscroll_status`（off/on/overscroll） |
| **Status line** | 常驻 | 状态栏（本身） | 常驻 |

除 swarm strip 外，底部没有其他动态成员条带。其余行都是临时性（排队提示、通知、donut）或配置显隐（overscroll）。

---

## 十、Todo 显示双通道（2026-08-25 00:50 追加）

### 1. 问题

顶部固定遮挡区域是 Todo 列表（每项带勾）。确认其显示控制方式。

### 2. 双通道对比（代码确认）

| 项 | `pin_todos` | `Alt+X` |
|----|-----------|---------|
| 位置 | 顶部（transcript 上方，sticky） | 聊天流内（作为一条消息） |
| 滚动 | ❌ 钉住，不随屏滚 | ✅ 随聊天滚动 |
| 内容 | todo + plan + goals（`todo_card_payload_json`） | 同样 `todo_card_payload_json` |
| 数据源 | session todos | session todos |
| 控制 | `[display] pin_todos = false`（配置） | `Alt+X`（运行时切换） |

### 3. 代码证据

**`pin_todos`（顶部固定）**：`crates/jcode-tui/src/tui/ui_viewport.rs`

```rust
// Pinned todo band (display.pin_todos): the full todo card rendered beneath
// the sticky previous-prompt preview, including at the top of the transcript.
let (pinned_todo_band, pinned_todo_more_line) =
    pinned_todo_band_lines(app, text_render_area.width, render_area.height);
```

**`Alt+X`（聊天内，随屏滚动）**：`crates/jcode-tui/src/tui/app/todos_view.rs:26-38`

```rust
/// Show the session todo list as an inline card in the chat transcript, or
/// dismiss it when the card is already the trailing message.
pub(super) fn toggle_todo_card(&mut self) {
    ...
    self.push_display_message(crate::tui::DisplayMessage::todos(content));
}
```

**键位定义**：
- `keybind.rs:406`：`todo_card: ToggleBinding::load(&cfg.keybindings.todo_card_toggle, 'x')`
- `config lib.rs:1036`：`todo_card_toggle: get("todo_card_toggle", "alt+x")`
- `input.rs:2324-2325`：`if app.toggle_keys.todo_card.matches(...) { app.toggle_todo_card(); }`

### 4. 操作方式

| 需求 | 操作 |
|------|------|
| 长期关闭顶部固定 band | `[display] pin_todos = false` |
| 临时查看 todo（关闭后） | `Alt+X` 唤起聊天内卡片，再按一次隐藏 |
| 自定义键位 | `[keybindings] todo_card_toggle = "alt+x"` |

**注意**：`Alt+X`（todo 卡）与 `Alt+I`（info widget 覆盖层）是两条独立路径；`Alt+X` 控制 pinned todo band / 聊天卡片，`Alt+I` 控制整个 info widget overlay。

---

### 5. 实际应用 （2026-08-25 00:53 追加）

在 `~/.jcode/config.toml` 设置：

```toml
[display]
pin_todos = false
```

- **实时生效**，无需重启，保存配置后屏幕立即清爽
- 顶部固定遮挡（Todo band）消失
- 临时查看 todo：按 `Alt+X` 唤起聊天内卡片

---


## 十一、Alt+N 面板重入设计方案（2026-08-25 01:29 追加）

### 1. 背景

worker 未销毁（server 成员表还在），但 15min 后广播保留到期，Alt+N 面板看不到（数据源被过滤）。

### 2. 关键事实（代码确认）

- `swarm list`（CommList）直接从 `swarm_members` 表读，**不受 15min 广播过滤影响**——46min 时仍能查到 worker（已实测）
- Alt+N 面板数据源 `remote_swarm_members` 来自广播（`SwarmStatus`），被 `member_in_status_broadcast` 过滤（live 成员 + terminal 15min 内）
- 问题本质：**TUI 面板与聊天 strip 共用一个被过滤的数据源**

### 3. swarm 调用串行性（代码确认）

```rust
// 同 swarm 内 spawn 串行（admission lock，每 swarm 一把互斥锁）
fn spawn_admission_lock(swarm_id: &str) -> Arc<Mutex<()>>
let admission_guard = admission_lock.lock().await;

// coordinator 单轮串行：await_members 阻塞当前轮次
```

**结论**：同一 coordinator await 期间不能并发发起新一组 spawn；不同 swarm（不同仓库/会话）互不影响。

### 4. 方案对比

**方案 A：面板拉取命令（推荐）**
- Alt+N 聚焦时 TUI 发一次 `CommList`（完整成员）刷新 `remote_swarm_members`
- 聊天 strip 仍用广播（轻量），面板打开时才拉全量
- 优点：不改 server 广播逻辑、不加带宽；面板"重入"天然满足
- 代价：加一条 TUI→server 一次性请求

**方案 B：广播分段（面板全量 + strip 精简）**
- 广播拆两部分：live 成员（照常）+ archived manifest（仅 id/label/status）
- 聊天 strip 只看 live，Alt+N 面板合并两者
- 优点：面板无需额外请求，实时性最好
- 代价：广播 payload 回涨（当初砍 15min 是为压 ~240KB/700 成员），需压缩

**方案 C：面板显示"过期条目"占位**
- 广播保留范围内显示；过期成员在面板显示灰色占位 + "点此查询"
- 点击时发 CommList 拉详情
- 优点：广播大小可控，交互明确
- 代价：多两次交互

### 5. 推荐

**方案 A**：面板打开时主动拉一次全量（CommList 已存在且返回完整成员），复用现有能力，不动广播过滤逻辑。最小改动、不影响后续新 swarm 执行（新 spawn 照常广播，面板合并显示）。

---

## 十二、同一协调者 swarm 并行化方案（2026-08-25 01:46 追加）

### 1. 需求

同一协调者让多组 swarm 任务并行跑，多组任务可被协调者跟踪管理做后续推进。

### 2. 现有基础（代码确认）

"并行"已有雏形，不需要从零造：

| 机制 | 代码位置 | 现状 |
|------|---------|------|
| `await_members` 后台模式 | `comm_await.rs` | `background=true` 时挂起 watcher，完成发 `SwarmAwaitCompleted` 通知，不阻塞 coordinator |
| `run_plan` 后台模式 | `communicate.rs:3152` | `background=true` 时走 `BackgroundTaskManager` + `bg` 工具跟踪进度/收结果 |
| 调度器串行防护 | `try_claim_run_plan_driver` | 同 session 只允许 1 个 run_plan driver（防双驱动抢工作） |

**结论**：同一协调者**已经可以**多组并行：
1. spawn 组 A → `await_members background=true`（挂后台）
2. spawn 组 B → `await_members background=true`（挂后台）
3. 模型继续做别的，两组完成通过通知回报

### 3. 改造方案（让"多组被跟踪管理"）

**方案 A：组 ID 化 await（推荐）**
- `await_members` 增加 `group_id` 参数，后台 watcher 按组注册
- 模型可 `swarm await_members group_id="review-batch"` 查询指定组进度
- `SwarmAwaitCompleted` 通知带回 `group_id`，模型可区分哪个组完成
- 改动量：`await_members_state.rs` 加组字段 + 查询按组过滤，约 50-100 行

**方案 B：复用 bg 工具做组管理**
- 每组 `run_plan` 后台任务天然有 task_id（`bg` 工具可查）
- 模型用 `bg action="list"` 列出所有并行组、`bg action="wait" task_id=...` 等组完成
- 改动量：几乎为 0，纯编排层用法
- 局限：`await_members`（非 run_plan）也并行时，组标识不统一

**方案 C：计划层面分组**
- 一个 `VersionedPlan` 内并行分支天然支持（无环 DAG 并发就绪节点）
- `run_plan` 已按图调度并发 worker，无需新机制
- 局限：那不是"多组"，是一组图的多节点并行

### 4. 并行风险与影响点

| 风险 | 具体表现 | 缓解 |
|------|---------|------|
| **协调者上下文混乱/幻觉** | 模型在两个组的报告间切换，容易把 A 组 worker 的结论归到 B 组；报告摘要混在一条消息里时标签混淆 | 方案 A 的 `group_id` 强制分组；reporter 输出按组分隔 |
| **worker 冲突** | 两组改同一文件 → 文件触发通知爆炸、互相覆盖 | 组间用 worktree 隔离（现有 worktree 机制）；或提示协调者划分文件域 |
| **并发预算挤占** | 组 A/B 合计 worker 数达 `swarm_max_concurrent_agents`（32）→ 触发容量恢复清理已完成 worker（C2 路径） | 每组限并发（`concurrency_limit` 参数），总和留余量 |
| **await 通知风暴** | 多组完成时间接近 → 多条 `SwarmAwaitCompleted` 通知排队，软中断抢占模型轮次 | 通知合并（同轮合并多组摘要）；`notify=false` 时攒批取 |
| **报告顺序不确定性** | 组 A 后发但先完成，模型按完成序处理，导致计划推进顺序错乱 | 明确约定：推进依赖用 `complete_node` + 图依赖，不靠完成通知顺序 |
| **同一 driver 冲突** | 两个 `run_plan` 同 session → 被 `try_claim_run_plan_driver` 拒绝 | 并行组用 `await_members` 而非双 `run_plan`；或不同 session 各跑一个 |

### 5. 关键设计约束

**并行 ≠ 在同一个模型轮次里混着记**。保证不出幻觉的核心是：**每一组任务的汇报在上下文里分区隔离**（组前缀/折叠/ref），模型推进时只基于当前组上下文——这就是 `group_id` + 折叠 UI 的价值。

---

## 十三、孤儿输出与 auto_poke 配置分析（2026-08-25 01:55 追加）

### 1. 孤儿输出问题

**现象**：每次新工具调用时，频繁出现 `Recovered orphaned tool output: call_...` 并附带 `- [deleted] sam-custom` 旧输出。

**原因**：2026-08-23 12:22 删除 lite 仓库上 `sam-custom` 分支的 `git push --force` 操作输出。该工具调用的结果在会话切换时未成功投递，系统在后台缓存了它。每次新工具调用后，底层框架尝试刷新缓存，把它带出来。

**影响**：纯视觉干扰，不影响功能。缓存排空后会自动消失。

**避免**：无法从本侧控制，新开会话（`/resume` 新建）不会出现该历史输出。

### 2. 程序更新与快捷键提示配置

**代码位置**：

- `crates/jcode-config-types/src/lib.rs:1075-1088`（`FeatureConfig` 段）：

```rust
pub check_updates: bool,  // 启动时检查更新，默认 true
```

- `crates/jcode-config-types/src/display.rs:97-98`（`DisplayConfig` 段）：

```rust
pub keybinding_hints: bool,  // 弹出"学这个快捷键"提示，默认 true
```

**实际修改**（2026-08-25 01:57）：

```bash
# ~/.jcode/config.toml:68
keybinding_hints = false

# ~/.jcode/config.toml:82
check_updates = false
```

### 3. self-dev 模式配置

**配置文件里没有 `no_selfdev` 配置项**。self-dev 只能通过 CLI 参数控制，无法在 `config.toml` 预设。

| 场景 | 操作 |
|------|------|
| 默认关闭 | 每次启动加 `jcode --no-selfdev`（或配置 shell 别名） |
| 临时开启 | 不加 `--no-selfdev` 自然就是 self-dev 模式 |
| 配置文件中预设 | ❌ 不支持，只能靠启动参数 |

建议用 shell 别名：

```bash
alias jcode='jcode --no-selfdev'
```

### 4. auto_poke 配置分析

**问题**：`/poke`（自动提示模型继续）默认开启，所有会话启动时自动触发。需要配置默认关闭。

**代码位置**：

- `crates/jcode-config-types/src/lib.rs:1085-1088`（`FeatureConfig` 段）：

```rust
/// Default state of auto-poke (automatic follow-up when the model stops with
/// incomplete todos). `/poke on` / `/poke off` still override this per session
/// (default: true)
pub auto_poke: bool,
```

- `crates/jcode-config-types/src/lib.rs:955-956`（`KeybindingsConfig` 段）：

```rust
pub auto_poke_toggle: String,  // "ctrl+p", 设 "" 禁用快捷键
```

- `crates/jcode-base/src/config/default_file.rs:283-285`：

```toml
# Auto-poke: automatically nudge the model to continue when it stops with
# incomplete todos. /poke on and /poke off still override this per session.
auto_poke = true
```

**配置明细**：

```toml
[features]
auto_poke = false        # 所有会话默认关闭 /poke

[keybindings]
auto_poke_toggle = ""    # 可选：禁用快捷键（设为 "" 即可）
```

- `auto_poke = false` 后，所有新会话启动时默认不自动 poke
- `/poke on` 仍可对单个会话临时开启
- 快捷键 `auto_poke_toggle = "ctrl+p"`，设 `""` 可禁用

**实际修改**（2026-08-25 01:49）：

```bash
# ~/.jcode/config.toml:86 改为
auto_poke = false
```

---

## 十四、Spawn Worker Bash 权限问题（2026-08-25 08:58 追加）

### 现象

Spawn 出来的 headless worker 无法执行 bash 命令，报错 `Shell execution is restricted in this environment`。

### 根因

Worker 的 bash 工具被 `bash_destructive_gate` 安全门拦截。spawn 的 worker 默认工具集不带 bash 执行权限。

### 配置文件控制

**配置文件里没有直接控制 spawn worker 工具集的配置项。**

| 控制方式 | 是否可配置 |
|---------|-----------|
| 配置文件 `config.toml` | ❌ 无对应项 |
| spawn 时传 `--tool-profile full` | ✅ 运行时参数 |
| spawn 时传 `--tools bash,read,write` | ✅ 运行时参数 |
| 模型路由提示 `swarm-prompt.md` | ⚠️ 可提示模型加参数，但不保证 |

### 绕过方式

在 spawn 指令中追加参数：

```text
"spawn 一个 worker，label='echo-test', 指定 --tool-profile full，执行 echo 123"
```

或者修改 `swarm-prompt.md` 路由提示，让模型 spawn 时默认指定工具集。

### 代码走查分析

**"Shell execution is restricted" 不是 jcode 代码层面的错误，而是 OS 层的 `Permission denied (os error 13)`。**

bash 工具执行命令的方式（`crates/jcode-app-core/src/tool/bash.rs`）：

```rust
// 非 Windows
TokioCommand::new("bash")  // 通过 OS 启动 bash 进程
    .arg("-c")
    .arg("echo 123")
```

**`os error 13`（EACCES）** 是 `execve()` 系统调用返回的，不是 jcode 的 `bash_destructive_gate` 在拦截（破坏性命令门禁会返回 `[bash] denied destructive command`），也不是 `disabled_tools` 配置在禁用（会返回 `Tool 'bash' is disabled`）。

可能原因：
1. bash 二进制本身不可执行（权限问题/路径问题）
2. 进程运行在受限环境（seccomp 禁止 fork/exec、容器安全策略）
3. 工作目录挂在 `noexec` mount 上

**这是运行环境层面的安全策略，不是 jcode 配置能解决的问题。**

---

## 十五、Swarm 操作指令全景（2026-08-25 10:55 追加）

### 1. 背景

问题："广播已关闭的 swarm 如何重入再显示？" 深化 —— 不只看文档结论，直接走代码盘点 swarm 到底有哪些可操作指令、分别怎么触发。

### 2. 指令分两层

| 层 | 触发者 | 入口 |
|----|--------|------|
| TUI 人类指令 | 用户打字/键盘 | `crates/jcode-tui/src/tui/app/commands.rs`、`keybind.rs` |
| swarm 工具指令 | agent（模型）调用 | `crates/jcode-app-core/src/tool/communicate.rs`（工具名 `swarm`，action 枚举） |

### 3. TUI 人类指令（打字/键盘触发）

| 输入 | 触发 | 效果 |
|------|------|------|
| `/swarm` 或 `/swarm status` | 回车 | 显示 swarm 开/关状态（不列成员） |
| `/swarm on` / `/swarm off` | 回车 | 本会话开关 swarm |
| `/swarm-prompt`（`/swarm-prompt edit`/`open`） | 回车 | 用 $EDITOR 打开 swarm 路由提示词：项目 `.jcode/swarm-prompt.md` → 全局 `~/.jcode/swarm-prompt.md` → 内置默认 |
| `/agents` 或 `/agents swarm` | 回车 | 打开 agent 模型配置选择器（跳 swarm 角色模型 override） |
| `/compact-notifications on/off` | 回车 | 折叠/展开 swarm/file-activity 通知卡 |
| `Alt+N` | 键盘 | 循环 chat → 面板 → 全屏 live 页面（依赖广播数据） |
| `Alt+↑/↓`、`Alt+j/k` | 面板聚焦 | 面板内选择成员 |
| `Alt+o` / `Alt+Enter` | 面板聚焦 | 选中成员 pop out 到新终端 |
| `Alt+Shift+p` | 面板聚焦 | 打开 swarm prompt |
| `Esc` | 面板聚焦 | 退出面板 |

### 4. swarm 工具指令（agent 调用，40 个 action）

触发方式：在 TUI 对主 agent 说自然语言，让它调用 `swarm` 工具（如"查一下 swarm 成员"→ `action=list`）。

**通信类**
- `share` / `share_append`(key,value)：共享/追加上下文
- `read`(key)：读共享上下文
- `message`(message)：广播（无目标）
- `dm`(message,to_session)：私聊
- `channel`(message,channel)：频道消息
- `list`：全部成员（CommList 直读 `swarm_members` 表，全量，不受 15min 广播过滤）
- `list_channels` / `channel_members`(channel)：频道列表/成员
- `subscribe_channel` / `unsubscribe_channel`：订阅/退订频道

**状态与查询（重入显示的关键）**
- `list`：发 `CommList` 直读成员表——文档实测 46min 仍能查到 worker 的命令
- `status`(target_session)：单个目标状态快照
- `summary`(target_session,limit)：工具调用摘要
- `read_context`(target_session)：读该会话上下文历史
- `report`(status,message,validation,follow_up)：汇报状态

**规划类**
- `propose_plan` / `approve_plan` / `reject_plan` / `plan_status`
- `task_graph`/`seed_graph` / `expand_node` / `complete_node` / `inject_gap` / `resync_plan`

**生成与管理类**
- `spawn`(label,prompt,model,spawn_mode)：生成 worker（label 必填）
- `stop` / `cleanup`：停 worker
- `assign_role`：分配 agent/coordinator 角色
- `list_models`：模型路由列表
- `start`/`start_task`/`wake`/`resume`/`retry`/`reassign`/`replace`/`salvage`：worker 状态操控
- `assign_task`/`assign_next`/`fill_slots`/`run_plan`/`await_members`：任务分配与执行

### 5. 关键结论

广播关闭后要重看成员，用 agent 触发 `swarm list`（或 `status`），自然语言示例：

> 用 swarm 工具 list 一下当前 swarm 的所有成员，包括已完成的

走 CommList 直读 server 成员表，24h 保留期内都能看到。Alt+N 面板依赖广播数据（已被过滤），不是重入途径；要面板可重入仍需实现方案 A（面板聚焦时发 CommList），当前未实现。

### 6. 实测：swarm list 广播关闭后成员可查（2026-08-25 11:11 追加）

#### 1. 实测命令

按第 5 节触发：对主 agent 说"用 swarm 工具 list 一下当前 swarm 有成员，包括已完成的"，工具调 `action=list`（CommList 直读成员表）。

#### 2. 实测结果（11 个成员）

**已完成/终止（广播 15min 窗口外，Alt+N 看不到但 list 能看到）**

| 成员 | 任务 | 状态 | 距现在 |
|------|------|------|--------|
| blossom | echoer-1 | failed | 10h |
| daisy | echoer-2 | failed | 10h |
| rose | echo-b | failed | 2h |
| maple | echo-c | failed | 2h |
| seedling | echo-d | failed | 2h |
| palmtree | echo-03a | failed | 2h |
| evergreen | echo-03b | ready / idle 2h | 2h |
| ant | echo-full | ready / idle 1h | 1h |
| tulip | echo-a | ready / idle 2h | 2h |

**活跃**

| 成员 | 状态 |
|------|------|
| clover ★（协调者，本会话） | running（8/10 todos） |

#### 3. 验证结论

- **blossom/daisy 已 10h，远超 15min 广播保留，`swarm list` 仍能查到** —— 与第十一节"CommList 不受广播过滤影响"完全一致
- 所有 echo worker 均因模型路由失败（st/deepseek-v4-flash endpoint 不可达）或 bash 权限（os error 13，见十四章）未能真正执行
- 成员带 report 字段（如 evergreen/ant/tulip 的完成报告），list 直接可见

#### 4. 与方案 A 的关系

> 方案 A 见第十一章"Alt+N 面板重入设计方案"第 4 节。

本次实测用的是 agent 主动调 `swarm list`（人→agent 自然语言触发），等价于方案 A 的核心数据获取（CommList）。差异仅在触发点：方案 A 是 Alt+N 面板聚焦时 TUI 自动发，本测试是对话触发。数据通道相同，都为重入显示提供了可行基础。
