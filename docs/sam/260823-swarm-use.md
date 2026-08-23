# jcode Swarm 使用问题记录

> 记录日期：2026-08-23

本文档记录在 jcode 项目中使用 Swarm 功能时遇到的问题和排查过程。

---

## 一、Alt+↑/↓ 在 Swarm 面板中无法选择 Agent

### 问题描述

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

### 根因：终端对 Alt+Arrow 键的修饰符处理不一致

查看 `swarm_panel_action_for_key`（第2176-2178行）：

```rust
KeyCode::Down | KeyCode::Char('j') if alt => SelectNext,
KeyCode::Up | KeyCode::Char('k') if alt => SelectPrev,
KeyCode::Char('o') | KeyCode::Enter if alt => SelectPopOut,
```

Alt+↑/↓ 要求 `KeyCode::Up/Down` **且** `modifiers` 包含 `ALT`。但许多终端（手机终端、Win10 的多数终端）对 Alt+Arrow 的处理方式是发送 `ESC [ A` / `ESC [ B` 序列，而不是 `Char('o')|ALT`。crossterm 收到后解析为 `KeyCode::Up/Down` 但 **modifiers 为空**（ALT 已消耗在 ESC 前缀中），导致 `if alt` 判断为 false，快捷键不匹配。

Alt+字母键（如 Alt+O）走的是字符编码路径，不受此影响，所以 Alt+O 能正常工作。

## 二、workaround：使用 Alt+j / Alt+k 替代

代码已经内置了字母替代键（第2176-2177行）：

| 功能 | 原快捷键 | 替代快捷键 | 状态 |
|------|---------|-----------|------|
| 选下一个 agent | Alt+↓ | **Alt+j** | ✅ 可用 |
| 选上一个 agent | Alt+↑ | **Alt+k** | ✅ 可用 |
| 弹出到新终端 | Alt+O | — | ✅ 可用 |
| 打开 swarm prompt | Alt+Shift+P | — | ✅ 可用 |

Alt+j/Alt+k 在 TUI 中没有被占用（仅在 Desktop2 中用作工作区切换）。

## 三、代码修复方向（待实现）

在 `swarm_panel_action_for_key` 中增加 Alt+Arrow 的 F-key 降级归一化，或在 crossterm event 解析层统一处理 Alt+Arrow 的修饰符丢失问题。

## 四、Swarm Agent 状态

| 审查任务 | Agent | 状态 |
|---------|-------|------|
| lib.rs API 代码审查 | hibiscus | ✅ 完成，发现 8 个改进点 |
| test_writer 测试补充 | blossom | ❌ 失败 |
| doc updater 文档更新 | daisy | ❌ 失败 |