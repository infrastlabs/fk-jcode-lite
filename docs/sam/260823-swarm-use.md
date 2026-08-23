# jcode Swarm 使用问题记录

> 记录日期：2026-08-23

本文档记录在 jcode 项目中使用 Swarm 功能时遇到的问题和排查过程。

---

## 一、Swarm 使用问题综述

### Alt+↑/↓ 在 Swarm 面板中无法选择 Agent

使用 Swarm 功能时，按下 Alt+↑ 或 Alt+↓ 无法切换到不同的 agent，反而被识别为滚动输入历史。但 Alt+N 能聚焦面板、Alt+O 能弹出到新终端，均正常工作。

### 代码调用链

按键输入从 `run` 函数开始（`crates/jcode-tui/src/tui/run.rs:340`），传递到 `handle_loop`，再到 `handle_tui_events`（`crates/jcode-tui/src/tui/app.rs:1873`）。最终到达 `handle_key_core`（第2892行），在 `handle_key_core` 之前，按键先经过 `handle_pre_control_shortcuts`（第2264行）。

`handle_key_core` 在第2661行遇到 Alt+↑/↓ 时通过 `is_prompt_recall_modifier` 判断触发输入历史翻滚：

```rust
if is_prompt_recall_modifier(modifiers, code) {
    app.toggle_prompt_recall(direction);
    return;
}
```

### 根因

Swarm 面板按键处理有严格的门控：

第2352行：
```rust
if app.swarm_panel_focused() && app.handle_swarm_panel_key(code, modifiers) {
    return true;
}
```
这里又有一层 `swarm_panel_focused()` 判断，加上 `inline_swarm_gallery_active()`（第2077行），双重门控。

按用户实际体验：Alt+N 能聚焦面板、Alt+O 能用，但 Alt+↑/↓ 不生效。这说明 `swarm_panel_focused` 已经是 true，门控不是问题。

### Alt+N 多按次的状态机

按用户实际观察：按一次 Alt+N 和连按两次的效果不同，两次会弹出更明显的窗口。这与 `cycle_swarm_panel_view`（第2015行）的状态机吻合：

```
当前状态                →  按 Alt+N 后状态
swarm_panel_focused=false → Controls（紧凑条带，显示在 status bar 上方）
swarm_panel_focused=true, full_page=false → FullPage（全屏页面）
swarm_panel_focused=true, full_page=true → Chat（退出面板）
```

两种模式（Controls 和 FullPage）都设置了 `swarm_panel_focused = true`。Alt+↑/↓ 在两种模式下都不可用（终端编码问题），Alt+j/Alt+k 在两种模式下都可用。

### 根因：终端对 Alt+Arrow 键的修饰符处理不一致

查看 `swarm_panel_action_for_key`（第2176-2178行）：

```rust
KeyCode::Down | KeyCode::Char('j') if alt => SelectNext,
KeyCode::Up | KeyCode::Char('k') if alt => SelectPrev,
KeyCode::Char('o') | KeyCode::Enter if alt => SelectPopOut,
```

Alt+↑/↓ 要求 `KeyCode::Up/Down` **且** `modifiers` 包含 `ALT`。但许多终端（手机终端、Win10 的多数终端）对 Alt+Arrow 的处理方式是发送 `ESC [ A` / `ESC [ B` 序列，而不是 `Char('o')|ALT`。crossterm 收到后解析为 `KeyCode::Up/Down` 但 **modifiers 为空**（ALT 已消耗在 ESC 前缀中），导致 `if alt` 判断为 false，快捷键不匹配。

Alt+字母键（如 Alt+O）走的是字符编码路径，不受此影响，所以 Alt+O 能正常工作。

### workaround：使用 Alt+j / Alt+k 替代

代码已经内置了字母替代键（第2176-2177行）：

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
```
swarm list
```
仅显示 running / idle 状态的 agent。

**已结束 agent 的历史**：

| 方式 | 用途 |
|------|------|
| `session_search query=swarm` | 搜索所有 swarm 相关会话，包括已完成的 worker |
| coordinator 会话对话历史 | 每个 worker 完成后自动转发 completion report 给 coordinator |
| `Alt+N` 进入 Swarm 面板（TUI） | 实时状态图（running/blocked/idle），但不显示已清理的 completed |

### 重入已结束的 Agent

根据 `docs/SWARM_ARCHITECTURE.md` Communication 章节：**Completed 或 idle 的 agent 不会自动 resume**，必须显式操作。

| 方法 | 用途 |
|------|------|
| `swarm message` + `delivery: "wake"` | DM 唤醒一个已存在的 agent |
| `swarm wake` | 唤醒指定 session |
| `swarm assign_task` | coordinator 分配新任务给该 agent |
| `swarm retry` | 对失败的 agent 重新分配同一任务 |
| `swarm reassign` | 把任务转给另一个 agent |
| `swarm spawn` | 重新 spawn 一个全新的（不重入旧的） |

最简单的方式：

```
swarm message to_session=<已结束的session_id或label> message="新指令" delivery="wake"
```

注意：如果 agent 已被 `cleanup` 清理（停止），则无法重入，只能 `spawn` 重新创建。

---