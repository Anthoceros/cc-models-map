<h1 align="center">cc-models-map</h1>

<p align="center">把 Claude Code 的档位别名（opus / sonnet / haiku / fable / smallfast）分别指向你本地 Claude Code Router（CCR）网关上的真实模型。</p>

<p align="center">
  <a href="./README.md">English</a> | <a href="./README.zh-CN.md">简体中文</a>
</p>

## 前提条件

- 已安装 Claude Code。
- 本机已安装并运行 [Claude Code Router](https://github.com/musistudio/claude-code-router)（CCR）。

## 能做什么

- 把任意档位映射到某个模型，例如「把 sonnet 档位映射到 MiniMax (China)/MiniMax-M3」。
- 查看五个档位当前各自指向什么。
- 列出你的网关可以路由到的模型。
- 重启 CCR，并确认某个档位的路由真能跑通。

## 整体流程

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./assets/architecture-dark.svg">
  <img alt="从 tier.sh 经 CCR 的 config.sqlite、重新生成的 wrapper、新 claude 会话、CCR 网关，到上游 provider 的配置流程" src="./assets/architecture.svg">
</picture>

[`tier.sh`](./tier.sh) 把单档字段写进 CCR 的 `config.sqlite`；重启 CCR 会重新生成 wrapper，为每个档位导出 `ANTHROPIC_DEFAULT_<TIER>_MODEL`。新开的 `claude --model <tier>` 会话在进程启动时捕获这个环境变量，再把 `/v1/messages` 发到 CCR 网关 `127.0.0.1:3456`，网关按 `Provider/model` 路由到上游。

## 安装

把下面这句发给你的 Agent：

> 安装这个 skill：https://github.com/Anthoceros/cc-models-map.git —— 把仓库里的 `SKILL.md` 和 `tier.sh` 放到 `~/.claude/skills/cc-models-map/`，并给 `tier.sh` 加执行权限。装完报告结果，先不要运行它的任何命令。

## 用法

把下面这句发给你的 Agent：

> 把 sonnet 档位映射到 MiniMax (China)/MiniMax-M3

它会改好映射、重启 CCR，并跑一次真实会话来确认路由生效。

## 注意

- 映射只对新启动的 Claude Code 会话生效，要新开一个会话才用得上。
- 模型要写成 `Provider/model` 格式，`Provider` 用 CCR 里显示的 provider 名（例如 `MiniMax (China)`）。裸的 Claude 别名（如 `claude-opus-4-5`）会被拒绝。
- 如果改完之后默认档开始报错，可能是 `~/.claude/settings.json` 里还留着一个指向已删除 provider 的 `ANTHROPIC_MODEL`。清掉它，或者显式指定档位。
