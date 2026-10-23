# subagent-routing

[English](README.md)

subagent-routing 是一条纯文本规则，教编码 agent（Cursor、Claude Code、Codex）怎么用 subagent。主 agent 先拆分任务，再按三档模型表给每个 subagent 选模型，并核对 subagent 交回的结论。

subagent 是主 agent 为一项任务另外启动的 agent。它在全新的上下文里工作，多个 subagent 可以并行。它也要花时间和钱，答案也可能出错。

规则常驻：agent 每个会话都会读它。另有一个详情文件，agent 只在特定情况下读，例如重跑，或和 skill 冲突时。项目没有 hook，也没有运行时代码。规则只是文本，没有任何机制强制 agent 遵守。

## 规则让 agent 做什么

1. 任务要改 2 个以上文件时，先说明哪些自己做、哪些并行派发、哪些放后台，再开工。
2. 按任务类型从模型表里选档。每一档可以填一个模型，也可以用逗号列出不同家族的模型（如 Claude 和 Gemini）。所选档位有与主模型同家族的模型时就用它；没有时默认继承主模型。不从模型表里取别的家族的模型；只有用户在消息里为某项活点名（只用于那项活），或正在运行的 skill 要求用不同厂商的模型时，才用别的家族的模型。
3. 模型表里有与主模型同家族的强档模型、且主模型较弱时，把强档的活（设计、诊断）派给强档 subagent。
4. 只在用户或正在运行的 skill 要求时才派评审 subagent，评审用标准档。
5. 要求 subagent 按顺序答：结论，证据，没把握的点。完整答案放在最后一条消息里。
6. 采用 subagent 的结论前，先自己核对 1-2 处关键证据。
7. subagent 因模型服务或连接错误中断时，接着续跑同一个 subagent（Cursor 里用 `resume` 传完整的 Agent ID）。subagent 的结果不合格时重跑一次：升一档重跑（更高一档没有同家族模型时继承主模型）；原本已是最高档或已继承主模型时，新开一个同模型 subagent 重跑一次。

如果 subagent 也加载同一份指令，它也会读到这条规则。规则让 subagent 跳过第 1、3 条，只在 prompt 要求时才再派 subagent。

模型表分三档。下表说明每一档适合的任务类型：

| 档位 | 任务类型 |
|---|---|
| 轻 | 只读查事实、查文档与出处、常规代码/Git/日志侦察、跑现成脚本/测试/命令并收集输出或报错 |
| 标准 | 跨模块综合分析、按固定细则判分、报告/数据事实核对、MR 跟进、独立代码/Spec/安全评审（首轮与增量复核）、方案已定的代码实现与评测 |
| 强 | 开放式方案设计、疑难根因诊断、要自己做设计决策的代码 |

只读检索或跑命令在轻和标准之间拿不准时，先用轻档；改代码、核对或分析在标准和强之间拿不准时，用标准档。

## 安装

需要 `git`，以及 PowerShell（Windows）或 Bash（macOS、Linux、Git Bash）。至少选一个 agent。下面的例子为 Claude Code 安装。

Windows：

```powershell
git clone https://github.com/Shengjingwa/subagent-routing.git
cd subagent-routing
./install.ps1 -Claude -Light haiku -Standard sonnet -Strong opus
```

如果 PowerShell 提示禁止运行脚本，改用这条命令启动：`powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Claude -Light haiku -Standard sonnet -Strong opus`。

macOS、Linux 或 Git Bash：

```bash
git clone https://github.com/Shengjingwa/subagent-routing.git
cd subagent-routing
./install.sh --claude --light haiku --standard sonnet --strong opus
```

安装后开一个新对话或新会话。

两个脚本的选项一一对应。下表第一列是 `install.ps1` 的写法，第二列是 `install.sh` 的写法，第三列是作用：

| `install.ps1` | `install.sh` | 作用 |
|---|---|---|
| `-Cursor` | `--cursor` | 写出 `out/cursor-rule.md`，并复制到剪贴板 |
| `-Claude` | `--claude` | 往 `CLAUDE.md` 写入一个带标记的块 |
| `-Codex` | `--codex` | 往 `AGENTS.md` 写入一个带标记的块 |
| `-Light`、`-Standard`、`-Strong` | `--light`、`--standard`、`--strong` | 设置某一档的模型 |
| `-Uninstall` | `--uninstall` | 删除脚本写入的内容 |
| `-NoClipboard` | `--no-clipboard` | 不把 Cursor 规则复制到剪贴板 |

每个 agent 都有单独的说明页，写明安装步骤、改动的文件和注意事项。说明页是英文。下表列出规则落点和说明页链接：

| 工具 | 规则落在哪里 | 说明页 |
|---|---|---|
| Cursor | `out/cursor-rule.md`，由你粘贴到 User Rules | [adapters/cursor](adapters/cursor/README.md) |
| Claude Code | `$CLAUDE_CONFIG_DIR` 或 `~/.claude` 里 `CLAUDE.md` 的一个块 | [adapters/claude](adapters/claude/README.md) |
| Codex | `$CODEX_HOME` 或 `~/.codex` 里 `AGENTS.md` 的一个块 | [adapters/codex](adapters/codex/README.md) |
| 其他 agent | 由你手工粘贴的文本 | [adapters/generic](adapters/generic/README.md) |

下表是示例档位模型。请换成你的 agent 接受的 subagent 模型名：

| 工具 | 轻 | 标准 | 强 |
|---|---|---|---|
| Cursor | `claude-haiku-5-5-thinking-xhigh` | `claude-sonnet-5-5-xhigh` | `claude-opus-5-5-xhigh` |
| Claude Code | `haiku` | `sonnet` | `opus` |
| Codex | 小而快的模型 | 中等规模的模型 | 主会话用的模型 |

所有 agent 通用的几点：

- 一次运行只设一组档位模型。每个 agent 认的模型名不同，所以每个 agent 单独运行一次。
- 没传的档位保留占位符，如 `<light-model>`。规则会让 agent 不给这一档设模型，并在每个会话里提醒你一次。
- 脚本保留文件原有内容，每次改动前写备份 `<文件>.subagent-routing.bak`。备份里是上一次改动之前的文件。再次运行时，它只替换自己的块。
- 注意：克隆目录不要移动。规则用绝对路径指向详情文件。移动后要重新运行脚本。

## 换档位模型

重新运行安装命令，写上新的模型名。每次都要传全三档，没传的档位会变回占位符。脚本会替换旧块。

- Cursor：把新的 `out/cursor-rule.md` 粘贴到旧的 User Rule 上。
- 其他 agent：直接改粘贴文本里的三行档位。

## 更新

先运行 `git pull`，再用同样的选项重新运行安装命令。

## 卸载

运行带卸载选项的安装命令：

```powershell
./install.ps1 -Claude -Codex -Uninstall
```

```bash
./install.sh --claude --codex --uninstall
```

脚本只删除自己写的块，文件其余内容保留。文件里只有这一个块时，脚本会删除整个文件，并保留备份。如果这个文件是符号链接，脚本保留链接，只清空它指向的文件。Codex 卸载时，`AGENTS.md` 和 `AGENTS.override.md` 里的块都会删除。

卸载后文件逐字节还原，每一行原来的换行符、BOM 和任何编码的文字都保留。原文件末尾没有换行时，安装会在块前补一个换行，并在开始标记里注明；卸载时再把文件末尾的换行去掉。如果你在块后面加了内容，这个换行会保留，免得两行连在一起。往一个空文件里安装，卸载时这个文件会被删除，和只装了这一个块的文件一样。

Cursor：在 Cursor Settings > Rules 里删除标题为 `subagent-routing` 的 User Rule。`-Cursor -Uninstall` 会删除 `out/cursor-rule.md`，并打印提醒。

## 本地补充文件

你可以把个人补充写在 `~/.subagent-routing.local.md`。Windows 上的路径是 `%USERPROFILE%\.subagent-routing.local.md`。安装脚本不创建这个文件，由你自己建。

文件里可以写你自己 skill 的角色分档，诸如此类。它和详情文件冲突时，以本地文件为准。你在对话里点名的模型仍然最优先。

agent 读详情文件时才会读这个文件。详情文件只在特定情况下读，例如升一档重跑时，或某个 skill 规定了怎么派 subagent 时。所以这个文件改变不了常驻规则，例如档位表。

## 相关项目

这些项目各自解决同一问题的一部分。下面的事实截至 2026-10-12。

- [foxhatleo/leos-agent](https://github.com/foxhatleo/leos-agent)：面向 Claude Code、Codex、Cursor 和 OpenCode 的策略层。它按档位路由模型和推理强度，另带评审关卡、hook 和派发日志。它的 README 写明不支持原生 Windows。
- [AqueGen/model-routing](https://github.com/AqueGen/model-routing)：Claude Code 插件，含固定模型的 subagent、一个路由 skill 和一个统计派发次数的 hook。
- [liuhl152/cursor-subagent-delegation](https://github.com/liuhl152/cursor-subagent-delegation)：Cursor 的规则和 skill。一个 `preToolUse` hook 会拒绝没写明模型的 `Task` 调用。它还记录委派日志。它依赖 Bash 和 `jq`。
- [obra/superpowers](https://github.com/obra/superpowers)：大型 skill 框架。它的 `subagent-driven-development` skill 里有一节选模型（cheap、standard、most capable）。

本项目的不同点：

- 只有文本：一条规则，一个详情文件。没有 hook，没有运行时。
- 一份规则文本用于三个 agent。有 Windows 和 macOS/Linux 两种安装脚本。
- 它管何时派发、怎么拆分、怎么评审、怎么核对结果，不只管用哪个模型。

hook 能强制执行一个选择，文本做不到。需要强制执行或派发日志时，请用上面的项目。

## 设计笔记

[docs/design.md](docs/design.md)（英文）说明为什么用规则文本而不用 hook，并列出作者的测量结果。

## 许可证

MIT。见 [LICENSE](LICENSE)。
