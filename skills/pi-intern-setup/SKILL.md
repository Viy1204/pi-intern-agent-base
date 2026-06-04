---
name: pi-intern-setup
description: "Pi 实习生智能体基座安装检查。用于首次安装或修复基座配置，包含 AGENTS.md 模板安装、飞书/lark-cli 检查清单、失败项汇总。"
---

# Pi Intern Setup

用于完成 Pi 实习生智能体基座的首次安装或修复。

## 初始化顺序

1. 运行环境检查。
2. 询问是否安装基座 `AGENTS.md`。
3. 检查 `lark-cli` 是否可用；不可用时输出安装/配置检查清单。
4. 引导用户运行 `/feishu setup` 配置飞书机器人桥接。
5. 引导用户运行 `/feishu status`，并在飞书里给机器人发送测试消息。

## 环境检查

先定位本 skill 目录里的脚本，再执行。

```powershell
$checkScript = Get-ChildItem -Path "$HOME\.pi\agent" -Recurse -Filter check-environment.ps1 |
  Where-Object { $_.FullName -like "*pi-intern-setup*scripts*" } |
  Select-Object -First 1 -ExpandProperty FullName

powershell -NoProfile -ExecutionPolicy Bypass -File $checkScript
```

检查结果中如果 `bash` 不可用，提示用户安装 Git for Windows，并把 `C:\Program Files\Git\bin` 加到 PATH。Windows 下 bridge 后台进程依赖 `bash`。

## 安装 AGENTS.md

当用户要求安装基座 `AGENTS.md` 时，先询问安装范围：

- 推荐：当前工作区 `.pi/AGENTS.md`
- 可选：全局 `~/.pi/agent/AGENTS.md`

默认不要覆盖已有文件。只有用户明确确认覆盖时，才给脚本传 `-Force`。

先定位本 skill 目录里的脚本，再执行。不要假设当前工作目录就是 package 根目录。

```powershell
$script = Get-ChildItem -Path "$HOME\.pi\agent" -Recurse -Filter install-agents.ps1 |
  Where-Object { $_.FullName -like "*pi-intern-setup*scripts*" } |
  Select-Object -First 1 -ExpandProperty FullName

# 推荐：写入当前工作区 .pi/AGENTS.md，不覆盖已有文件
powershell -NoProfile -ExecutionPolicy Bypass -File $script -Scope project

# 指定工作区
powershell -NoProfile -ExecutionPolicy Bypass -File $script -Scope project -Workspace "C:\path\to\workspace"

# 全局安装。若已有文件，必须先取得用户明确确认，再加 -Force
powershell -NoProfile -ExecutionPolicy Bypass -File $script -Scope global
```

## 检查清单

安装或配置失败时，按下面格式回复：

- 已完成：
- 失败项：
- 下一步：

## 飞书 bridge

通用基座已内置 `pi-intern-feishu-bridge`，命令沿用：

```text
/feishu setup
/feishu start
/feishu status
/feishu debug
/feishu stop
```

`lark-cli` 和 bridge 是两套配置：

- `lark-cli`：Pi 主动操作飞书 API。
- `pi-intern-feishu-bridge`：飞书消息进入 Pi。

## 规则

- 不输出密钥、token、appSecret、cookie。
- 展示配置时，对敏感字段打码。
- 涉及飞书操作时，优先使用 `lark-cli`。
- 写入、删除、移动文件、发消息、改权限前，先确认用户意图。
