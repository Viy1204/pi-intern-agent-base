---
name: pi-intern-base-installer
description: Use this skill whenever the user wants Claude Code to install, configure, or bootstrap the Pi Intern Agent base package for a colleague. This includes prompts like "安装 Pi 实习生", "配置 pi intern", "帮我装通用基座", "setup pi-intern", or "公司同事第一次安装 Pi 实习生". The skill checks local prerequisites, verifies GitHub access, installs the Pi base package, writes the optional AGENTS.md, and checks Feishu/Lark CLI status.
---

# Pi Intern Base Installer

这个 skill 让 Claude Code 帮用户完成 Pi 实习生通用基座安装。目标用户是普通同事，不要求他们理解仓库结构或 Pi package 原理。

## What This Skill Does

- 检查本机是否有 `git`、`node`、`npm`、`bash`、`pi`、`lark-cli`。
- 检查 Node 子进程是否能启动 Git Bash，避免飞书 bridge 报 `spawn bash ENOENT`。
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
   - bridge 的 `bashPath`、`nodeCanSpawnBash` 是否就绪。
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

8. 首次启动 Pi 时提醒用户按顺序执行：

   ```text
   /login
   /feishu setup
   /feishu status
   ```

   如果飞书插件配置后没反应，提示运行：

   ```text
   /feishu restart
   ```

## Common Fixes

- `git` 不存在：运行 `winget install --id Git.Git -e --source winget`。官网：https://git-scm.com/download/win
- `node` 或 `npm` 不存在：运行 `winget install --id OpenJS.NodeJS.LTS -e --source winget`。官网：https://nodejs.org/en/download
- `claude` 不存在：先安装 Node.js，再运行 `npm install -g @anthropic-ai/claude-code`。官方文档：https://docs.claude.com/en/docs/claude-code/setup
- `pi` 不存在：先安装 Node.js，再运行 `npm install -g @earendil-works/pi-coding-agent`。npm：https://www.npmjs.com/package/@earendil-works/pi-coding-agent
- `lark-cli` 不存在：先安装 Node.js，再运行 `npx @larksuite/cli@latest install`。GitHub：https://github.com/larksuite/cli
- GitHub 弹窗被取消：让用户手动运行 `git ls-remote https://github.com/Viy1204/pi-intern-agent-base.git HEAD`，按 Git Credential Manager 提示登录后再重跑 dry run。
- GitHub 返回 `Repository not found`：通常是当前 GitHub 账号没有私有仓库权限，请管理员把用户加入 `Viy1204/pi-intern-agent-base`。
- `pi install` 报 `not a git repository`：可能是上次中断留下了坏缓存。关闭 pi/git 进程后，经用户确认再清理 `~\.pi\agent\git\github.com\Viy1204\pi-intern-agent-base`。
- `spawn bash ENOENT`：安装 Git for Windows，关闭并重新打开终端；仍失败时设置 `FEISHU_BRIDGE_BASH` 指向 `C:\Program Files\Git\usr\bin\bash.exe`。
- `No models available`：启动 Pi 后先运行 `/login` 配模型/API。
- `winget` 不存在：打开 Microsoft 官方说明安装 Windows Package Manager：https://learn.microsoft.com/windows/package-manager/winget/

每次安装新工具后，请让用户关闭并重新打开 Claude Code 或终端，再重新运行本 skill。
