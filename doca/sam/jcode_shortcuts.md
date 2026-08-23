# jcode 快捷键完整汇总（按类别归类）

> 整理日期：2026-08-23

基于代码库 (`crates/jcode-config-types/src/keybindings.rs`, `crates/jcode-tui/src/tui/app/input.rs`, `crates/jcode-tui/src/tui/keybind.rs`, `crates/jcode-desktop2/src/keymap.rs`) 和 [jcode.sh/docs](https://jcode.sh/docs) 官网文档整理。

> 注：TUI (终端) 快捷键与 Desktop2 (GUI) 快捷键有部分差异。除非特别标注，以下均为 **TUI** 默认快捷键。macOS 与 Windows/Linux 有差异的会分别标注。

---

## 一、输入与提交 (Input & Submit)

| 快捷键 | 作用 | 平台差异 |
|--------|------|----------|
| **Enter** | 发送输入（立即发送，与正在工作的 agent 交错） | 通用 |
| **Shift+Enter** | 插入换行（不提交） | 通用 |
| **Ctrl+Enter** / **Cmd+Enter** | 交替提交行为（queue_mode 的反面） | 通用 |
| **Alt+Enter** | 插入换行（同 Shift+Enter） | 通用 |
| **Ctrl+V** / **Alt+V** / **Cmd+V** | 从剪贴板粘贴 | 通用 |
| **Tab** | 自动补全（斜杠命令补全） | 通用 |
| **BackTab (Shift+Tab)** | 切换模型收藏夹热键 | 通用 |

## 二、光标移动与编辑 (Cursor Movement & Editing)

### Emacs 风格
| 快捷键 | 作用 |
|--------|------|
| **Ctrl+A** | 光标移到行首 (TUI)；全选 (Desktop2) |
| **Ctrl+E** | 光标移到行尾 |
| **Ctrl+B** | 光标向后移一个单词 |
| **Ctrl+F** | 光标向前移一个单词 |
| **Ctrl+K** | 删除光标到行尾 (kill-to-end) |
| **Ctrl+U** | 删除光标到行首 (kill-to-start) |
| **Ctrl+W** | 删除光标前一个单词 |
| **Ctrl+D** | 删除光标下字符 (forward delete，有文本时)；中断/退出 (空行时) |
| **Ctrl+Z** | 撤销输入修改 |
| **Ctrl+X** | 剪切整行到剪贴板 |
| **Ctrl+Y** | 重做 (Windows/TUI) |

### Alt/Option 风格
| 快捷键 | 作用 |
|--------|------|
| **Alt+B** | 光标向后移一个单词 |
| **Alt+F** | 光标向前移一个单词 |
| **Alt+D** | 删除光标后一个单词 (delete word forward) |
| **Alt+Left** | 光标向后移一个单词 |
| **Alt+Right** | 光标向前移一个单词 |
| **Alt+Backspace** / **Alt+Delete** | 删除光标前一个单词 |
| **Alt+V** | 粘贴 |

### Cmd/Super 风格 (TUI)
| 快捷键 | 作用 |
|--------|------|
| **Cmd+Left** / **Cmd+Home** / **Cmd+A** | 光标移到行首 |
| **Cmd+Right** / **Cmd+End** / **Cmd+E** | 光标移到行尾 |
| **Cmd+Backspace** / **Cmd+Delete** | 删除光标前一个单词 |
| **Cmd+Z** | 撤销 |
| **Cmd+X** | 剪切 |
| **Cmd+V** | 粘贴 |
| **Cmd+L** | 终端风格清屏 |

### 基本导航
| 快捷键 | 作用 |
|--------|------|
| **Left** | 光标左移一个字符 |
| **Right** | 光标右移一个字符 |
| **Up** | 上一条历史输入（多行模式下为上一行） |
| **Down** | 下一条历史输入（多行模式下为下一行） |
| **Home** | 光标移到行首 |
| **End** | 光标移到行尾 |
| **Backspace** | 删除光标前一个字符 |
| **Delete** | 删除光标后一个字符 |
| **Ctrl+Left** | 光标向后移一个单词 |
| **Ctrl+Right** | 光标向前移一个单词 |

## 三、滚动与导航 (Scrolling & Navigation)

### 逐行滚动
| 快捷键 | 作用 |
|--------|------|
| **Ctrl+Shift+K** | 向上滚动一行 |
| **Ctrl+Shift+J** | 向下滚动一行 |
| **Up** | 向上滚动一行（输入框为空时） |
| **Down** | 向下滚动一行（输入框为空时） |

### 翻页滚动
| 快捷键 | 作用 |
|--------|------|
| **Alt+U** (macOS: **Option+U**) | 向上滚动一页 |
| **Alt+D** (macOS: **Option+D**) | 向下滚动一页 |
| **PageUp** | 向上滚动一页 |
| **PageDown** | 向下滚动一页 |

### Prompt 跳转
| 快捷键 | 作用 |
|--------|------|
| **Ctrl+K** | 跳转到上一个用户 prompt |
| **Ctrl+J** | 跳转到下一个用户 prompt |
| **Ctrl+[** | 跳转到上一个用户 prompt (别名) |
| **Ctrl+]** | 跳转到下一个用户 prompt (别名) |
| **Ctrl+5** ~ **Ctrl+9** | 按最近使用排名跳转到第 N 个 prompt |

### 书签
| 快捷键 | 作用 |
|--------|------|
| **Ctrl+G** | 切换滚动书签（标记位置，跳到底部，再按返回） |

### 滚动到顶部/底部
| 快捷键 | 作用 |
|--------|------|
| **Alt+Home** | 滚动到 transcript 顶部 |
| **Alt+End** | 滚动到 transcript 底部 |

## 四、面板切换 (Panel Toggles)

| 快捷键 | 作用 | 默认值 |
|--------|------|--------|
| **Alt+M** (macOS: Option+M) | 切换侧面板 | `alt+m` |
| **Alt+Y** (macOS: Option+Y) | 切换复制/选择模式 | `alt+y` |
| **Alt+T** (macOS: Option+T) | 切换图表窗格位置 | `alt+t` |
| **Alt+S** (macOS: Option+S) | 切换打字滚动锁定 | `alt+s` |
| **Alt+G** (macOS: Option+G) | 切换/循环 diff 显示模式 | `alt+g` |
| **Alt+I** (macOS: Option+I) | 切换信息小部件 | `alt+i` |
| **Alt+X** (macOS: Option+X) | 显示/隐藏 todo 卡片 | `alt+x` |
| **Alt+N** (macOS: Option+N) | 聚焦 inline swarm 面板 | `alt+n` |

### 侧面板尺寸预设 (Ctrl+数字)
| 快捷键 | 作用 |
|--------|------|
| **Ctrl+1** | 侧面板宽度设为 25% |
| **Ctrl+2** | 侧面板宽度设为 50% |
| **Ctrl+3** | 侧面板宽度设为 75% |
| **Ctrl+4** | 侧面板宽度设为 100% |

## 五、模型与推理 (Model & Reasoning)

| 快捷键 | 作用 | 平台差异 |
|--------|------|----------|
| **Ctrl+Tab** | 切换到下一个模型 | 通用 |
| **Ctrl+Shift+Tab** | 切换到上一个模型 | 通用 |
| **Alt+Right** | 增加推理 effort | Win/Linux |
| **Alt+Left** | 减少推理 effort | Win/Linux |
| **Cmd+Right** | 增加推理 effort | macOS |
| **Cmd+Left** | 减少推理 effort | macOS |
| **Ctrl+Y** | 接受 post-error fallback 提议（切换模型/认证方式并重发） | 通用 |

## 六、工作区与窗口 (Workspace & Window)

### 工作区导航 (Niri 风格)
| 快捷键 | 作用 |
|--------|------|
| **Alt+H** (macOS: Option+H) | 移动到左侧工作区 |
| **Alt+J** (macOS: Option+J) | 移动到下方工作区 |
| **Alt+K** (macOS: Option+K) | 移动到上方工作区 |
| **Alt+L** (macOS: Option+L) | 移动到右侧工作区 |

### 新终端/新会话
| 快捷键 | 作用 | 平台差异 |
|--------|------|----------|
| **Alt+Shift+;** | 在当前目录打开新终端会话 | Win/Linux |
| **Cmd+Shift+;** | 在当前目录打开新终端会话 | macOS |
| **Alt+R** | 打开 session picker (/resume) | Win/Linux |
| **Cmd+B** | 打开 session picker (/resume) | macOS |

### 全局启动热键 (系统级)
| 快捷键 | 作用 |
|--------|------|
| **Cmd+; / Super+; / Alt+;** | 在 home 目录启动新 jcode |
| **Cmd+' / Super+' / Alt+'** | 在最近项目目录启动新 jcode |
| **Cmd+Shift+' / Super+Shift+' / Alt+Shift+'** | 启动 jcode self-dev 会话 |

## 七、特殊功能键 (Special Keys)

| 快捷键 | 作用 |
|--------|------|
| **Esc** | 取消（处理中：中断；有输入：清空；空输入：跟随底部） |
| **Ctrl+C** | 处理中时中断，空闲且输入为空时退出 |
| **Ctrl+D** | 处理中时中断，空闲且输入为空时退出（有文本时删除字符） |
| **Ctrl+L** | 终端风格清屏 |
| **Ctrl+R** | 打开 prompt 历史搜索 |
| **Ctrl+P** | 切换 auto-poke |
| **Ctrl+S** | 切换输入 stash |
| **Ctrl+T** | 切换队列模式 |
| **Alt+C** | 切换居中布局 |
| **Alt+Shift+E** | 展开编辑 diff 徽章 |
| **Alt+Shift+I** | 切换 inline 图片展开/折叠 |
| **F1** | 打开帮助 (Desktop2) |

### 复制徽章快捷键 (Alt+字母)
| 快捷键 | 作用 |
|--------|------|
| **Alt+<字母>** | 复制可见的徽章目标内容（根据上下文动态变化） |
| **Alt+A** | 输入框为空时复制聊天视口内容到剪贴板 |

## 八、Session Picker 快捷键

### 主界面
| 快捷键 | 作用 |
|--------|------|
| **Up / Down** | 上下选择 |
| **Enter** | 恢复选中会话（默认在当前终端） |
| **Ctrl+Enter** | 在新终端中恢复 |
| **Space** | 切换多选 |
| **Esc** | 关闭 / 清除搜索 |
| **q** | 关闭 |
| **Ctrl+C** | 关闭 |
| **/** | 搜索 |
| **s** | 循环切换过滤模式 |
| **S** | 反向循环切换过滤模式 |
| **d** | 切换测试会话显示 |
| **R / B / b** | 恢复崩溃的会话组 |
| **T** | 开始 Claude takeover 确认 |

### 搜索模式
| 快捷键 | 作用 |
|--------|------|
| **Esc** | 退出搜索 |
| **Enter** | 提交搜索并选择 |
| **Backspace** | 删除搜索字符 |
| **Ctrl+W** / **Ctrl+Backspace** | 删除搜索前一个词 |
| **Ctrl+U** | 清除搜索 |
| **Ctrl+J / Ctrl+N** | 向下选择 |
| **Ctrl+K / Ctrl+P** | 向上选择 |
| **Ctrl+C** | 关闭 |
| **Up / Down** | 上下选择 |

### Claude takeover 确认
| 快捷键 | 作用 |
|--------|------|
| **Enter / Y / y** | 确认 takeover |
| **Esc / N / n / q** | 拒绝 takeover |
| **Ctrl+C** | 关闭 |

## 九、桌面端独有 (Desktop2 GUI)

### 文本编辑 (Web 风格)
| 快捷键 | 作用 |
|--------|------|
| **Ctrl+A / Cmd+A** | 全选 |
| **Ctrl+C / Cmd+C** | 复制（有选中时）/ 中断（无选中时） |
| **Ctrl+X / Cmd+X** | 剪切 |
| **Ctrl+V / Cmd+V** | 粘贴 |
| **Ctrl+Z / Cmd+Z** | 撤销 |
| **Ctrl+Shift+Z / Ctrl+Y** | 重做 |
| **Ctrl+Shift+C** | 复制选择 |
| **Ctrl+Shift+A** | 全选（别名） |

### 光标移动 (Desktop2)
| 快捷键 | 作用 |
|--------|------|
| **Up / Down** | 历史浏览 |
| **Shift+Up / Shift+Down** | 扩展选择一行 |
| **Ctrl+Home** | 光标到文档开头 |
| **Ctrl+End** | 光标到文档末尾 |
| **Ctrl+Shift+Home** | 扩展到文档开头 |
| **Ctrl+Shift+End** | 扩展到文档末尾 |

### 会话面板 (Desktop2)
| 快捷键 | 作用 |
|--------|------|
| **Ctrl+Tab** | 下一个会话面板 |
| **Ctrl+Shift+Tab** | 上一个会话面板 |
| **Ctrl+PageDown** | 下一个会话面板 |
| **Ctrl+PageUp** | 上一个会话面板 |
| **Ctrl+T / Cmd+T / Ctrl+Shift+N** | 新建会话面板 |
| **Ctrl+R** | 打开/关闭 session resume 面板 |
| **Ctrl+,** | 打开/关闭设置面板 |
| **Ctrl+M** | 打开/关闭模型选择器 |
| **Ctrl+Alt+Left/Right/Up/Down** | 会话面板导航 |
| **Super+H/J/K/L** | 会话面板导航 (niri 风格) |
| **Ctrl+Alt+Shift+Left/Right** | 调整面板大小 |

### 缩放与主题 (Desktop2)
| 快捷键 | 作用 |
|--------|------|
| **Ctrl+= / Ctrl++** | 放大 |
| **Ctrl+-** | 缩小 |
| **Ctrl+0** | 重置缩放 |
| **Ctrl+Shift+D** | 切换亮/暗主题 |
| **Ctrl+Shift+R** | 手动重新加载激活的构建 |

### 空间概览 (Desktop2)
| 快捷键 | 作用 |
|--------|------|
| **Ctrl+Alt+Space** | 打开空间概览 |
| **Arrow keys** | 导航 |
| **H / J / K / L** (vim 风格) | 导航 |
| **Tab** | 下一个 |
| **Enter / Space** | 确认选择 |
| **Esc** | 取消 |

### Resume 面板 (Desktop2)
| 快捷键 | 作用 |
|--------|------|
| **Up / Down** | 上下选择 |
| **Left / Right** | 折叠/展开项目 |
| **PageUp / PageDown** | 跳转到上/下一个项目组 |
| **Tab** | 下一个 |
| **Shift+Tab** | 上一个 |
| **Enter** | 确认选择 |
| **Esc** | 取消 |
| **Backspace** | 删除搜索字符 |
| **Ctrl+R** | 关闭 resume 面板 |
| **Ctrl+C / Ctrl+D / Ctrl+G** | 取消 |
| **Ctrl+J / Ctrl+N** | 向下 |
| **Ctrl+K / Ctrl+P** | 向上 |
| **Space** | 输入搜索 |

## 十、Swarm 面板快捷键

| 快捷键 | 作用 |
|--------|------|
| **Alt+N** | 聚焦/循环 inline swarm 面板 |
| **Alt+↑ / Alt+↓** | 选择 agent |
| **Alt+O** | 弹出 agent 到新终端 |
| **Alt+Shift+P** | 打开 swarm prompt |
| **Esc** | 退出 swarm 面板 |

## 十一、其他快捷键

| 快捷键 | 作用 |
|--------|------|
| **Alt+5** | 打开 onboarding 模拟器 (开发者工具) |
| **Cmd+5** | 打开 onboarding 模拟器 (macOS 开发者工具) |
| **Alt+Space** / **Cmd+Space** | 切换 "下一条 prompt 发送到新会话" 路由 |
| **Mouse scroll wheel** | 滚动 transcript（需启用 mouse_capture） |

## 配置方式

所有快捷键均可通过 `~/.jcode/config.toml` 中 `[keybindings]` 部分自定义：

```toml
[keybindings]
scroll_up = "ctrl+k"
scroll_down = "ctrl+j"
side_panel_toggle = "alt+m"
# 设为 "" 禁用
auto_poke_toggle = ""
```

使用 `/hotkeys` 或 `/keys` 命令查看当前激活的快捷键及其冲突检测结果。