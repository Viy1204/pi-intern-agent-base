---
name: pi-intern-base-installer
description: Use this skill whenever the user wants Claude Code to install, configure, or bootstrap the Pi Intern Agent base package for a colleague. This includes prompts like "安装 Pi 实习生", "配置 pi intern", "帮我装通用基座", "setup pi-intern", or "公司同事第一次安装 Pi 实习生". The skill checks local prerequisites, verifies GitHub access, installs the Pi base package, writes the optional AGENTS.md, and checks Feishu/Lark CLI status.
---

# Pi Intern Base Installer

这个 skill 让 Claude Code 帮用户完成 Pi 实习生通用基座安装。目标用户是普通同事，不要求他们理解仓库结构或 Pi package 原理。

## What This Skill Does

- 检查本机是否有 `git`、`node`、`npm`、`bash`、`pi`、`lark-cli`。
- 检查是否能访问 GitHub 私有仓库 `Viy1204/pi-intern-agent-base`。
- 安装通用 Pi 实习生基座：`pi install git:github.com/Viy1204/pi-intern-agent-base@v0.1.0`。
- 在当前工作区安装 `.pi/AGENTS.md`，已有文件时不覆盖。
- 检查飞书/Lark CLI 登录状态，但不输出 token、appSecret、cookie。
- 失败时给用户一份小白可读的检查清单。

## Safety Rules

- 运行安装前，先告诉用户将执行哪些操作，并等待明确确认。
- 不输出 token、appSecret、cookie、access token、refresh token。
- 不覆盖已有 `.pi/AGENTS.md`，除非用户明确要求。
- 如果用户问 HR 专属能力，告诉他需要另一个 HR 安装 skill，不要从本 skill 安装 HR 包。

## Recommended Flow

1. 用中文确认用户要安装的是“通用基座”。
2. 先运行 dry run：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-pi-intern-base.ps1 -Workspace "<当前工作区>" -DryRun
   ```

3. 根据 dry run 结果说明：
   - 已满足的条件。
   - 缺少的工具。
   - 是否有 GitHub 仓库权限。
   - 是否可以继续安装。
4. 如果缺少 `git`、`node`、`npm` 或 `pi`，停止安装，给出补装清单。
5. 如果只是缺少 `lark-cli`，可以继续安装基座，但提醒飞书能力之后还要补配。
6. 用户确认后运行：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-pi-intern-base.ps1 -Workspace "<当前工作区>" -Yes
   ```

7. 结束时用这个格式回复：

   ```text
   已完成：
   - ...

   未完成：
   - ...

   下一步：
   - ...
   ```

## Common Fixes

- `git` 不存在：安装 Git for Windows，并重新打开 Claude Code。
- `node` 或 `npm` 不存在：安装 Node.js LTS，并重新打开 Claude Code。
- `pi` 不存在：安装 Pi Agent 或公司指定的兼容客户端。
- GitHub 没权限：请管理员把用户加入 `Viy1204/pi-intern-agent-base` 私有仓库。
- `lark-cli` 不存在：先完成基座安装，再按公司飞书 CLI 指引配置。
