# jcode Swarm 使用问题记录

> 记录日期：2026-08-23

本文档记录在 jcode 项目中使用 Swarm 功能时遇到的问题和排查过程。

---

## 一、Swarm 面板切换按键问题：Alt+↑/↓失效根因与 workaround

### Alt+↑/↓ 在 Swarm 面板中无法选择 Agent

使用 Swarm 功能时，按下 Alt+↑ 或 Alt+↓ 无法切换到不同的 agent，反而被识别为滚动输入历史。但 Alt+N 能聚焦面板、Alt+O 能弹出到新终端，均正常工作。

### 代码调用链

按键输入从 `run` 函数开始（`crates/jcode-tui/src/tui/run.rs:340`），传递到 `handle_loop`，再到 `handle_tui_events`（`crates/jcode-tui/src/tui/app.rs:1873`）。最终到达 `handle_key_core`（第 2892 行），在 `handle_key_core` 之前，按键先经过 `handle_pre_control_shortcuts`（第 2264 行）。

`handle_key_core` 在第 2661 行遇到 Alt+↑/↓ 时通过 `is_prompt_recall_modifier` 判断触发输入历史翻滚：

```rust
if is_prompt_recall_modifier(modifiers, code) {
    app.toggle_prompt_recall(direction);
    return;
}
```

### 根因

Swarm 面板按键处理有严格的门控：

第 2352 行：
```rust
if app.swarm_panel_focused() && app.handle_swarm_panel_key(code, modifiers) {
    return true;
}
```
这里又有一层 `swarm_panel_focused()` 判断，加上 `inline_swarm_gallery_active()`（第 2077 行），双重门控。

按用户实际体验：Alt+N 能聚焦面板、Alt+O 能用，但 Alt+↑/↓ 不生效。这说明 `swarm_panel_focused` 已经是 true，门控不是问题。

### Alt+N 多按次的状态机

按用户实际观察：按一次 Alt+N 和连按两次的效果不同，两次会弹出更明显的窗口。这与 `cycle_swarm_panel_view`（第 2015 行）的状态机吻合：

```
当前状态                →  按 Alt+N 后状态
swarm_panel_focused=false → Controls（紧凑条带，显示在 status bar 上方）
swarm_panel_focused=true, full_page=false → FullPage（全屏页面）
swarm_panel_focused=true, full_page=true → Chat（退出面板）
```

两种模式（Controls 和 FullPage）都设置了 `swarm_panel_focused = true`。Alt+↑/↓ 在两种模式下都不可用（终端编码问题），Alt+j/Alt+k 在两种模式下都可用。

### 根因：终端对 Alt+Arrow 键的修饰符处理不一致

查看 `swarm_panel_action_for_key`（第 2176-2178 行）：

```rust
KeyCode::Down | KeyCode::Char('j') if alt => SelectNext,
KeyCode::Up | KeyCode::Char('k') if alt => SelectPrev,
KeyCode::Char('o') | KeyCode::Enter if alt => SelectPopOut,
```

Alt+↑/↓ 要求 `KeyCode::Up/Down` **且** `modifiers` 包含 `ALT`。但许多终端（手机终端、Win10 的多数终端）对 Alt+Arrow 的处理方式是发送 `ESC [ A` / `ESC [ B` 序列，而不是 `Char('o')|ALT`。crossterm 收到后解析为 `KeyCode::Up/Down` 但 **modifiers 为空**（ALT 已消耗在 ESC 前缀中），导致 `if alt` 判断为 false，快捷键不匹配。

Alt+ 字母键（如 Alt+O）走的是字符编码路径，不受此影响，所以 Alt+O 能正常工作。

### workaround：使用 Alt+j / Alt+k 替代

代码已经内置了字母替代键（第 2176-2177 行）：

| 功能 | 原快捷键 | 替代快捷键 | 状态 |
|------|---------|-----------|------|
| 选下一个 agent | Alt+↓ | **Alt+j** | ✅ 可用 |
| 选上一个 agent | Alt+↑ | **Alt+k** | ✅ 可用 |
| 弹出到新终端 | Alt+O | — | ✅ 可用 |
| 打开 swarm prompt | Alt+Shift+P | — | ✅ 可用 |

Alt+j/Alt+k 在 TUI 中没有被占用（仅在 Desktop2 中用作工作区切换）。

### 代码修复方向（待实现）

在 `swarm_panel_action_for_key` 中增加 Alt+Arrow 的 F-key 降级归一化，或在 crossterm event 解析层统一处理 Alt+Arrow 的修饰符丢失问题。

---

## 二、查看执行过的 Swarm 列表与重入已结束的 Agent

### 查看历史记录

**当前活跃 agent**：

- **TUI**：按 `Alt+N` 进入 Swarm 面板，可以看到实时状态图（running/blocked/idle）
- **Agent 内部工具**：使用 `swarm list` 内部 API 调用
- **语言指令**：在 TUI 中说"列出所有代理"，模型自动调用 `swarm list`

仅显示 running / idle 状态的 agent。

**已结束 agent 的历史**：

| 方式 | 用途 |
|------|------|
| `session_search query=swarm` | 搜索所有 swarm 相关会话，包括已完成的 worker |
| coordinator 会话对话历史 | 每个 worker 完成后自动转发 completion report 给 coordinator |
| `Alt+N` 进入 Swarm 面板（TUI） | 实时状态图（running/blocked/idle），但不显示已清理的 completed |
| "告诉我 xxx 的状态" | 语言指令触发 `swarm status` |

### 重入已结束的 Agent

根据 `docs/SWARM_ARCHITECTURE.md` Communication 章节：**Completed 或 idle 的 agent 不会自动 resume**，必须显式操作。

#### 可用方法对比

| 方法 | 用途 | 执行方式 | 权限要求 |
|------|------|----------|----------|
| `Alt+j/k` + 输入指令 | TUI 内切换到 agent 并发送新消息 | TUI 快捷键，最推荐 | 无 |
| `jcode debug -S <id> message` | CLI 发送消息到指定 session | 需要先设置 `JCODE_DEBUG_CONTROL=1` | admin |
| "给 xxx 发消息继续工作" | 语言指令触发 `dm` / `message` | TUI 自然语言 | 任意成员 |
| "唤醒 idle 的 xxx" | 语言指令触发 `wake` | TUI 自然语言 | 建议 coordinator |
| "重新分配这个任务给另一个代理" | 语言指令触发 `reassign` | TUI 自然语言 | 需 coordinator |
| `swarm assign_task` | coordinator 分配新任务给该 agent | 通过 coordinator 界面或 `swarm assign` 命令 | coordinator |
| `swarm retry` | 对失败的 agent 重新分配同一任务 | 通过 failure report 自动触发或手动 `swarm retry` | coordinator |
| `swarm spawn` | 重新 spawn 一个全新的（不重入旧的） | `swarm spawn` 或 `jcode self-dev` 重新启动 | 无 |

#### 具体操作流程

**TUI 方式（推荐）**：
1. 按 `Alt+N` 进入 Swarm 面板
2. 使用 `Alt+j` 或 `Alt+k` 导航到目标 agent
3. 直接输入新指令即可

**CLI 方式（仅限调试场景）**：
```bash
# 前提条件：设置环境变量启用 debug socket
export JCODE_DEBUG_CONTROL=1

# 1. 启动 server（如果未运行）
jcode debug start

# 2. 查看 session 列表获取 agent ID
jcode debug list

# 3. 发送消息到指定 session
jcode debug -S <agent_session_id> message "新指令"
```

注意：CLI 命令仅用于调试，生产环境请使用 TUI。

注意：`jcode` 没有独立的 `swarm` shell 子命令。上述 `swarm list`、`swarm message` 等是**Agent 内部工具 API**，不在 CLI 层面暴露。

**重要提示**：如果 agent 已被 `cleanup` 清理（停止），则无法重入，只能 `spawn` 重新创建。

---
## 三、Swarm 工具 Action 触发方式（2026-08-23 15:53:40 追加）

### 核心机制：自然语言指令 → 模型自动调用 swarm 工具

根据 `260822-swarm.md` 第五节，swarm 工具提供 35+ 个 action（spawn、dm、broadcast、assign_task、await_members 等）。用户在 **TUI 外部** 如何触发这些 action？

#### 答案：直接告诉模型"想做什么"，模型自动选择对应 action

| 用户说 | 模型内部调用 |
|---------|-------------|
| "生成一个代理审查 api.rs" | `swarm { action: "spawn", label: "...", prompt: "..." }` |
| "给 api reviewer 发消息补充边界情况" | `swarm { action: "dm", to_session: "...", message: "..." }` |
| "等所有代理完成后汇总结果" | `swarm { action: "await_members", mode: "all" }` |
| "清理已完成的代理" | `swarm { action: "cleanup" }` |

#### 关键要点

1. **用户无需记住具体 action 名**：只描述意图，模型自己决定调用哪个 action
2. **没有 CLI 命令暴露这些 action**：必须通过对话触发
3. **TUI 有快捷入口但有限**：`Alt+N` 面板 + `Alt+j/k` 导航是最高效的直接操作
4. **设置 `/effort swarm` 后模型更主动**：会自主 decompose 任务并 spawn 多个代理

#### 两种触发模式

| 模式 | 触发方式 | 适用场景 |
|------|---------|----------|
| **显式手动** | 直接指示："spawn 3 个代理分别做 X/Y/Z" | 明确知道要并行做什么 |
| **隐式自动** | `/effort swarm` + "重构模块 A" | 让模型自主分解并行 |

**示例对比**：

```text
# 显式：用户指定结构
"并行生成 3 个代理：
 1) api reviewer 审查接口
 2) test writer 写单元测试
 3) doc updater 更新文档
 等全部完成"
↓ 模型依次调用 spawn×3 + await_members

# 隐式：模型自主决策  
/effort swarm
"重构 src/parser.rs，拆成三个独立模块"
↓ 模型判断需要 3 个 agent，自行 spawn 并分配任务
```

注意：无论哪种模式，最终都是模型调用 swarm 工具的某个 action。区别在于前者由用户指定结构，后者由模型基于系统提示自主决策。

### Swarm 历史轮次查看与重入（补充说明）

jcode 区分两种"历史"概念：

#### A. 会话级切换（不同 jcode 窗口/会话）

| 操作 | 语言指令示例 | 实际效果 |
|------|-------------|----------|
| 列出所有历史会话 | "列出我之前运行过的会话" | 触发 `/resume` 会话选择器 |
| 切换到某个会话 | "我想回到 api reviewer 的对话" | `/resume` 后选择对应 session |
| 查看活跃会话状态 | "哪些会话还在运行？" | `/active` 管理器 |
| 查看待处理会话 | "还有哪些待处理的？" | `/catchup` 选择器 |

**核心命令**：
- `/resume` — 打开会话选择器（最常用）
- `/active` — 管理 working vs ready 状态的会话
- `/catchup` — 查看挂起的会话

#### B. Swarm 内部 Agent 轮次

| 场景 | 能否重入 | 方法 |
|------|---------|------|
| 已完成但未 cleanup 的 agent | ✅ 可以 | TUI: `Alt+N` → `Alt+j/k` 选择 → 输入新指令<br>语言："给 test writer 发消息继续写测试" |
| 已被 cleanup 的 agent | ❌ 无法直接恢复 | 只能通过 `session_search query="test writer"` 搜索全局历史 |
| 正在运行的 agent | ✅ 可中断追加 | `/poke` 或直接向 coordinator 描述要追加的任务 |

**关键区别**：
- `/resume`、`/active`、`/catchup` 是**Jcode 内置 slash command**，直接输入即可，无需自然语言
- swarm action（list/dm/wake 等）必须通过**自然语言描述意图**，由模型自动调用对应 tool
- 被 `cleanup` 的 agent 永久无法重入，只能从全局搜索中找记录
