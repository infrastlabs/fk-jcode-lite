# jcode 仓库结构与 API 调用链路分析

> 分析时间：2026-08-22
> 分支：`sam-custom`（`sam-custom` 相对 `master` 差 78 个 commit，源码改动 84 个文件 / +3284 −333 行；多为 `jcode-tui`、`jcode-app-core`、`cli`、`sdk` 的 UI / 命令 / 测试变更）
> 版本：v0.79.1（binary `jcode` 位于 `~/.jcode/builds/versions/0.79.1/jcode`）
> 代码规模：整个仓库（`crates/* + src/*`）约 **52 万行 Rust**（含测试），80+ crate。

---

## 一、仓库顶层结构

```
fk-jcode/
├─ Cargo.toml                        # workspace 根
├─ src/                              # jcode 可执行入口（CLI / daemon / bin）
│  ├─ main.rs
│  ├─ lib.rs
│  ├─ cli/                          # CLI 参数、命令分发（args.rs, commands.rs, dispatch.rs, startup.rs, auth_test/）
│  └─ bin/                          # 辅助 bin
├─ crates/                           # 80+ 功能 crate（模块化，按职责拆）
│  ├─ jcode-base/                   # 214 文件，核心：provider 抽象、config、compaction、live_tests、auth、logging、memory…
│  ├─ jcode-tui/                    # 274 文件（tui/app/…），TUI 界面：会话、消息、tool display、session picker、todo card、scroll
│  ├─ jcode-app-core/               # 253 文件，"应用核心"：会话持久化、session 生命周期、swarm、memory sidecar、jade relay
│  ├─ jcode-provider-openrouter-runtime/   # OpenAI-compatible / OpenRouter 流式运行（含 429 重试、SSE 解析、KV cache 追踪）
│  ├─ jcode-provider-openrouter/       # OpenRouter 请求/响应协议构造
│  ├─ jcode-provider-openai(-runtime)/   # OpenAI 官方 API
│  ├─ jcode-provider-anthropic(-runtime)/# Anthropic（Claude）
│  ├─ jcode-provider-<vendor>/      # 各家 provider：azure, bedrock, gemini, deepseek, moonshot, mistral, opencode, cerebras, cursor, copilot…
│  ├─ jcode-provider-core/          # 通用 provider 工具：retry_after, fingerprint, attempt_tracker, transport
│  ├─ jcode-protocol/               # TUI/daemon 之间的 wire protocol
│  ├─ jcode-transport/              # IPC 传输
│  ├─ jcode-tool-core / jcode-tool-types/ # tool（bash, read, edit, side_panel, memory…）定义
│  ├─ jcode-compaction-core/        # 会话压缩核心
│  ├─ jcode-sdk/                    # 外部程序调用 jcode 的 SDK（structured 输出）
│  ├─ jcode-swarm-core/             # 多 agent 协调
│  ├─ jcode-embedding / jcode-memory-types/  # 本地 embedding 与 memory
│  ├─ jcode-selfdev-types/          # 自开发模式（build / reload）
│  ├─ jcode-desktop2/               # 桌面 app（非 TUI 主线，本次不动）
│  └─ …
├─ docs/sam/                       # 项目内分析报告
│  ├─ 260821-vers.md
│  ├─ 260822-forks.md
│  ├─ 260822-swarm.md
│  ├─ 260822-axonhub-429.md         ← 本次分析文档
│  └─ 260822-repo-structure.md      ← 本文件
└─ scripts/                        # 开发/发布脚本
```

---

## 二、一次 OpenAI-compatible 请求（axonhub 场景）完整链路

以 `default_provider = "axonhub"`、`default_model = "st/sensenova-6.8-flash-lite"`、`base_url = "http://localhost:8090/v1"` 为例：

```
TUI 事件（用户 Enter）
  │
  ├─ crates/jcode-tui/src/tui/app/turn.rs
  │    apply_openai_native_compaction()  ← 如果会话接近阈值，先压缩
  │    native_compaction_threshold_tokens  ← 来自 [provider].openai_native_compaction_threshold_tokens（已改 200000→100000）
  │    产出 compaction 事件，触发 provider.complete()
  │
  ├─ crates/jcode-base/src/provider/mod.rs
  │    active_provider_fork()            ← 拿到当前 active provider
  │    native_compaction_threshold_tokens()
  │    stream_idle_timeout_for_effort()
  │
  ├─ crates/jcode-provider-openrouter-runtime/src/openrouter_provider_impl.rs
  │    fn complete(&self, messages, tools, system, _)
  │       ├─ 构造 OpenAI 格式 request JSON
  │       │    {"model", "messages", "stream": true, "tools", "stream_options": {"include_usage": true}, …}
  │       │    （axonhub 走 !supports_provider_features 分支，不带 OpenRouter 专用 provider 路由）
  │       ├─ fingerprint::log_provider_canonical_input()
  │       └─ tokio::spawn → run_stream_with_retries(...)
  │
  ├─ crates/jcode-provider-openrouter-runtime/src/openrouter_sse_stream.rs
  │    run_stream_with_retries(...)
  │       for attempt in 0..max_retries  { max_retries = 8 }
  │         ├─ API stream attempt N/M …（写入 ~/.jcode/logs/jcode-YYYY-MM-DD.log）
  │         ├─ stream_response(...)
  │         │    POST {api_base}/chat/completions
  │         │       Accept-Encoding: identity
  │         │       Bearer {AXONHUB_API_KEY}
  │         │    ├─ 200 → 建 SSE stream → loop 读 chunk → 发 StreamEvent 到 tx
  │         │    └─ 4xx/5xx → parse HTTP status → 构建 Error
  │         └─ is_retryable_error() ?
  │              429 可重试  / 4xx 非重试 / 502|503|504|stream error|eof 可重试
  │              next_retry_delay = Retry-After 或 1s 起步指数退避，封顶 retry_backoff_cap_secs（30）
  │
  ├─ crates/jcode-provider-core/src/retry_after.rs
  │    retry_delay() / retry_after() / MAX_RETRY_AFTER = 60s
  │
  └─ StreamEvent 回到 TUI / daemon → 显示 → 用户看到 "Streaming"
```

HTTP 网络细节：
- 使用 `reqwest::Client` 发 `POST {api_base}/chat/completions`。
- 重试时用 `fresh_transport_client()`（新建 TCP+TLS），避免复用损坏连接。
- 流式响应解析在 `OpenRouterStream`（SSE chunk 逐 token 发出）。
- 空闲超时 `stream_idle_timeout_secs`（180s）按 effort 乘数放大，防止深思考模型超时。

---

## 三、关键文件清单（后续调试/修改可对照）

| 位置 | 作用 |
|------|------|
| `crates/jcode-provider-openrouter-runtime/src/openrouter_provider_impl.rs` | complete() 入口，构造 request JSON |
| `crates/jcode-provider-openrouter-runtime/src/openrouter_sse_stream.rs` | 重试循环、SSE 解析、429 判定 |
| `crates/jcode-provider-core/src/retry_after.rs` | Retry-After / 退避算法 |
| `crates/jcode-provider-core/src/attempt_tracker.rs` | 尝试追踪、`retry_backoff_delay` |
| `crates/jcode-base/src/provider/mod.rs` | provider 抽象层、compaction 阈值 |
| `crates/jcode-base/src/compaction.rs` | 会话压缩、`discard_oversized_openai_native_compaction` |
| `crates/jcode-base/src/config/env_overrides.rs` | 配置与环境变量覆盖 |
| `crates/jcode-base/src/config.rs` | `config()` 全局缓存、指纹检测自动 reload |
| `crates/jcode-tui/src/tui/app/turn.rs` | TUI 回合执行、native compaction 触发 |
| `crates/jcode-tui/src/tui/app.rs` | KV_CACHE_USAGE 日志输出 |

---

## 四、本次改动后的实测（切到 sensenova-6.8-flash-lite 后）

`~/.jcode/config.toml`：`default_model = "st/sensenova-6.8-flash-lite"`，`openai_native_compaction_threshold_tokens = 100000`。备份 `config.toml.bak.20260823-011525`。config 文件修改后自动 hot-reload（`config()` 用指纹缓存 + 1s 检查间隔）。

直连 `http://localhost:8090/v1` 测试（与 jcode 同一路由，绕过 TUI 层，直接量化代理+上游表现）：

| 场景 | 结果 |
|------|------|
| 非流式单次（13 prompt tokens） | HTTP 200，TTFH **0.58s**，body 706B，含 `reasoning_content` |
| 流式 3 句回答 | HTTP 200，TTFH **3.23s**（模型先出 thinking），总耗时 3.49s，body 3534B |
| 连发 5 次 ping（`stream=false`） | **5/5 全 200**，TTFH 0.46 / 0.43 / 0.74 / 0.37 / 0.45s |

与之前的 `mscope/glm-5.2` 对比：

| | 之前（mscope/glm-5.2） | 现在（st/sensenova-6.8-flash-lite） |
|---|---|---|
| 连续 5 次 200 率 | 约 1/5（多 429） | 5/5 |
| 首次响应耗时 | 4-13s（多为 429，非真实首字） | 0.37-0.74s（真实首字） |
| TTFH 稳定性 | 抖得厉害，且多为假性（429） | 稳定，方差小 |

结论：切到 `st/sensenova-6.8-flash-lite` 后**请求质量显著改善，RPM 窗口外的稳定通道**，5 次连发全部即时成功，验证了"maki 用同系列 6.7 渠道稳定"的判断。

> 注：`openai_native_compaction_threshold_tokens` 从 200000 → 100000 的效果需跑长会话才能观测（更早日前压缩，把单请求 tokens 压到 RPM 窗口外）；本次改动是"请求更小 + 模型更稳"双管齐下。

---

## 五、值得注意的架构观察

1. **provider 与 runtime 拆成两层**：`jcode-provider-<vendor>` 处理协议（构造 request / 解析 response），`jcode-provider-<vendor>-runtime` 处理传输/重试/流式。跨 provider 共用 `jcode-provider-core`（retry_after、fingerprint、attempt_tracker、transport）。
2. **OpenAI-compatible 走 OpenRouter 兼容代码路径**：`axonhub`（type=open-ai-compatible）走 `jcode-provider-openrouter-runtime`，但 `supports_provider_features=false`，因此不带 OpenRouter 专有字段（`provider.routing`、`thinking`），只发 OpenAI 标准 body + `stream_options: {include_usage: true}`。
3. **compaction 是阈值驱动 + 显式事件**：超过 `openai_native_compaction_threshold_tokens` 时会压缩历史消息，压缩结果以 `reasoning_content` / `encrypted_content` 形态插入会话；本次把阈值 200000 → 100000，期望更早压缩、把单请求压到 RPM 窗口外。
4. **429 退避目前不够激进**：`retry_backoff_cap_secs=30`，而上游 RPM 窗口实测 60s+，建议调到 60。
5. **自定义 provider 不走 failover**：`same_provider_account_failover` 只对"多账号同厂商"生效，自定义 openai-compatible 只有单一路由/单一 key，失败只能反复打同一个代理。