---
name: cc-models-map
description: 设置 Claude Code 的 opus / sonnet / haiku / fable / small-fast 档位分别映射到哪个真实模型（经 CCR 本地网关），并能重启 CCR、跑真实会话测试路由是否生效。触发词：档位映射、模型映射、sonnet 映射、opus 映射、haiku 映射、设置 sonnet、claude 档位、tier mapping、model tier、把 sonnet 换成、各档位模型、测试档位。
---

# cc-models-map

把 Claude Code 的档位别名（opus / sonnet / haiku …）映射到本地网关上的真实模型，并验证路由。

适用于用 [Claude Code Router](https://github.com/musistudio/claude-code-router)（CCR）做后端、想按档位指定不同模型的场景。

## 关键事实（本机实测）

- **配置源**：`~/.claude-code-router/config.sqlite` 的 `app_config.default` → `profile.claudeCode.{opusModel,sonnetModel,haikuModel,fableModel,smallFastModel}`，同时写 `profile.profiles[default-claude-code]` 同名字段。值为 `Provider/model` 字符串（`Provider` 必须是 CCR 里的 provider 显示名，如 `MiniMax (China)`、`Workbuddy API`）。
- **传播链路**：改 sqlite 后，**重启 CCR** 会重新生成 `bin/ccr-claude-code-wrapper-default-claude-code`，里面把每个档位导出为 `ANTHROPIC_DEFAULT_<TIER>_MODEL`。Claude Code 进程按 `--model opus|sonnet|haiku` 选用对应变量。
- **只对新进程生效**：已运行的会话（包括当前会话）环境变量是启动时快照的，改完必须**新开**会话。
- **网关不接受裸 Claude 别名**：`claude-opus-4-5` 之类会 400（`Model ... is not configured`）。必须映射到 `Provider/model`。
- **`[1m]` 后缀**：CCR 可能生成 `MiniMax (China)/MiniMax-M3[1m]`（1M 上下文标记）。网关能正常解析，无害。
- **`unrecognized_model` 警告**：映射值不在 claude 内置模型表里时会打一条，纯提示，不影响路由。
- **`~/.claude/settings.json` 里可能有陈旧的 `ANTHROPIC_MODEL`**（指向已删除的 provider），默认档会 400。用 `--model <tier>` 不受影响；若默认档也要能用，把它清掉或改成有效值。

## 用法

脚本：`tier.sh`（同目录）。所有命令：

```bash
S=~/.claude/skills/cc-models-map/tier.sh

bash $S check [命令]         # 只做依赖检查（可指定针对哪个命令，默认 get）
bash $S list                 # 列出网关可用 provider/model
bash $S get                  # 显示当前各档位映射
bash $S set sonnet "MiniMax (China)/MiniMax-M3"   # 设置（自动备份）
bash $S restart              # 重启 CCR 并等网关恢复
bash $S test sonnet          # 跑真实会话测路由
```

**依赖检查**：`list` / `set` / `restart` / `test` 执行前会自动检查所需依赖，缺项即中止（退出码 1）。也可单独跑 `check <命令>` 预检。检查项按命令区分：

| 命令 | 额外检查 |
|---|---|
| `get` / `backup` | 仅 python3+sqlite3、配置可读 |
| `list` | + curl、key 文件、**网关在线** |
| `test` | + curl、key 文件、网关在线、wrapper、claude 可执行文件 |
| `restart` | + curl、key 文件、AppImage、pkill、setsid |

## 标准流程

1. `bash $S list` —— 确认目标 `Provider/model` 在可用列表里（会自动预检；网关离线会提示先 `restart`）。
2. `bash $S set <tier> "<Provider/model>"` —— 每个档位一次；会自动备份到 `~/.claude-code-router/_backup-tier-map/<时间戳>/`。
3. `bash $S restart` —— 重启 CCR（会短暂中断网关；**当前会话后端就是它**，几秒后恢复）。
4. `bash $S test <tier>` —— 用 CCR 新生成的环境跑一次 `claude --model <tier>`，并打印网关最近路由。看到响应 + 网关日志里对应 provider/模型 200 即成功。
5. 在 Claude 桌面 App 里**新开一个会话**、选对应档位，即为实际效果。

## 恢复

```bash
~/.claude-code-router/_backup-tier-map/<时间戳>/restore.sh
```

恢复后同样需 `bash $S restart` 才生效。

## 注意

- 重启 CCR 会中断正在跑的会话几秒（网关随 App 重启）。脚本用 `setsid nohup` 分离启动，即使调用方进程被中断也能拉起。
- 不要用 `cp` 覆盖运行中的 `config.sqlite`；本技能用 sqlite3 就地更新单字段，避免破坏 WAL。
- 若换机器 / 换 CCR 版本导致路径变化，改脚本顶部的 `CCR_DIR` / `GATEWAY` / `WRAPPER` 常量。
