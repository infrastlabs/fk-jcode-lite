# Swarm 使用问题记录

> 整理日期：2026-08-23
> 记录 Swarm 使用过程中遇到的问题、分析与解决方法，持续补充。

---

## 一、Swarm 面板 Alt+Up/Down 失效：变成了输入框历史翻滚

> 记录日期：2026-08-23

### 问题描述

Swarm 模式下，按下 swarm 面板焦点快捷键（默认 Alt+N），随后 Alt+Up/Down 方向键无法选择 agent，而是触发了输入框的历史翻滚。

### 代码调用链

用户按下 **Alt+Up** 时，`handle_key_core` 中的处理顺序：

```
handle_key_core(KeyCode::Up, ALT)
  └→ handle_pre_control_shortcuts()          [input.rs:2979]
       └→ swarm_panel_focused() &&            [input.rs:2352]
            handle_swarm_panel_key(Up, ALT)
            └→ !inline_swarm_gallery_active()?  [tui_state.rs:2077]
                 ↓ 如果 gallery 不活跃 → 返回 false，继续往下走
       └→ handle_alt_key() → 不处理 Up/Down   [input.rs:2398]
       └→ handle_navigation_shortcuts() → 不匹配 [input.rs:2410]
       └→ 返回 false
  └→ code == KeyCode::Up &&                    [input.rs:2991]
       is_prompt_recall_modifier(ALT)  ← 这里捕获了 Alt+Up！
       → 触发输入框历史翻滚
```

### 根因：`inline_swarm_gallery_active()` 返回 false

`handle_swarm_panel_key` 在 `tui_state.rs:2077` 检查：

```rust
if !self.swarm_panel_focused || !self.inline_swarm_gallery_active() {
    return false;  // ← 返回 false，Alt+Up 未被 swarm 消费
}
```

`inline_swarm_gallery_active()` 在 `tui_state.rs:1686` 需要三个条件**全部**满足：

```rust
fn inline_swarm_gallery_active(&self) -> bool {
    self.swarm_enabled                                    // ① swarm feature 开启
        && matches!(config().agents.swarm_spawn_mode, Inline)  // ② spawn mode = Inline
        && !self.inline_swarm_members().is_empty()         // ③ 有 swarm 成员
}
```

**关键问题在第③条**：`inline_swarm_members()` 通过 `filter_inline_swarm_subtree` 按 `report_back_to_session_id` 过滤，只返回**当前 session 直接 spawn 的子 agent**。如果当前 session 是其他 session spawn 出来的 worker（即你本人是某个 swarm agent 的子 session），或者刚刚 spawn 的 agents 已完成并从成员列表中移除，则 `inline_swarm_members()` 返回空列表。

### 连锁反应

1. 用户按 Alt+N（swarm focus 键）→ `cycle_swarm_panel_view()` 发现 gallery 不活跃 → **不设置焦点**，直接返回 Chat
2. 用户以为进入了 swarm 模式，但实际上焦点没设上
3. 按 Alt+Up → `handle_swarm_panel_key` 返回 false → 穿透到 `is_prompt_recall_modifier(ALT)` → 触发历史翻滚

### 结论

**这不是一个 bug，而是一个设计约束**：swarm inline gallery 只在当前 session 有直接 spawn 的子 agent 时才激活。如果当前 session 本身是 worker（被其他 session spawn 出来的），或者没有活跃的子 agent，则 Alt+Up/Down 不会被 swarm 面板拦截，而是回退到输入历史。

要确认，可以检查你是否在一个被 spawn 出来的 worker session 中，或者 swarm agents 是否已在 `await_members` 完成后被清理。

### 相关代码位置

| 文件 | 函数 | 行号 |
|------|------|------|
| `crates/jcode-tui/src/tui/app/input.rs` | `handle_key_core` | 2892 |
| `crates/jcode-tui/src/tui/app/input.rs` | `handle_pre_control_shortcuts` | 2264 |
| `crates/jcode-tui/src/tui/app/input.rs` | `is_prompt_recall_modifier` | 1261 |
| `crates/jcode-tui/src/tui/app/tui_state.rs` | `handle_swarm_panel_key` | 2072 |
| `crates/jcode-tui/src/tui/app/tui_state.rs` | `inline_swarm_gallery_active` | 1686 |
| `crates/jcode-tui/src/tui/app/tui_state.rs` | `cycle_swarm_panel_view` | 2015 |
| `crates/jcode-tui/src/tui/app/tui_state.rs` | `swarm_panel_action_for_key` | 2158 |