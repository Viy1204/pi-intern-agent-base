# Pi 实习生智能体基座安装说明

## 适用对象

这份说明用于安装通用 Pi 实习生智能体基座。通用基座不包含任何部门专属 skill。

## 新电脑准备

如果电脑上还没有任何 agent 或开发工具，请先准备：

- Pi Agent 或支持 Pi package/skill 的兼容客户端
- Git
- Node.js LTS，建议 Node.js 20 或更高版本
- Git Bash，Windows 安装 Git for Windows 时通常会一起安装
- GitHub 私有仓库访问权限
- `lark-cli`，用于飞书能力

检查命令：

```powershell
pi --version
git --version
node --version
npm --version
bash --version
lark-cli --version
```

缺工具时按下面补装：

| 缺少工具 | Windows 安装命令 | 官网 / 说明 |
| --- | --- | --- |
| `winget` | 按 Microsoft 说明安装或修复 App Installer | https://learn.microsoft.com/windows/package-manager/winget/ |
| `git` | `winget install --id Git.Git -e --source winget` | https://git-scm.com/download/win |
| `node` / `npm` | `winget install --id OpenJS.NodeJS.LTS -e --source winget` | https://nodejs.org/en/download |
| `claude` | `npm install -g @anthropic-ai/claude-code` | https://docs.claude.com/en/docs/claude-code/setup |
| `pi` | `npm install -g @earendil-works/pi-coding-agent` | https://www.npmjs.com/package/@earendil-works/pi-coding-agent |
| `lark-cli` | `npx @larksuite/cli@latest install` | https://github.com/larksuite/cli |

## 安装

如果同事已经有 Claude Code，推荐先安装 Claude Code installer skill：

```powershell
git clone https://github.com/Viy1204/pi-intern-agent-base.git
cd pi-intern-agent-base
New-Item -ItemType Directory -Force "$HOME\.claude\skills"
Copy-Item -Recurse -Force .\claude\skills\pi-intern-base-installer "$HOME\.claude\skills\pi-intern-base-installer"
```

之后重新打开 Claude Code，直接说：

```text
帮我安装 Pi 实习生通用基座
```

如果不使用 Claude Code，则直接安装 Pi 基座：

```bash
pi install git:github.com/Viy1204/pi-intern-agent-base@v0.1.1
```

私有仓库需要先确认你有 GitHub 访问权限。

## 初始化

进入 Pi 后，让 Pi 执行：

```text
使用 pi-intern-setup，帮我完成基座初始化
```

初始化会引导完成：

- 安装当前工作区 `.pi/AGENTS.md`
- 检查 `lark-cli`
- 检查 Git Bash / Node / Git
- 引导 `/login` 配置模型/API
- 引导 `/feishu setup`
- 验证 `/feishu status`

第一次打开 Pi 后，推荐按顺序输入：

```text
/login
/feishu setup
/feishu status
```

如果 `/feishu setup` 后没有反应，输入：

```text
/feishu restart
```

## 飞书

飞书能力分两层：

- `lark-cli`：用于文档、日历、表格、IM 等飞书 API 操作
- `pi-intern-feishu-bridge`：用于在飞书里直接和 Pi 对话

不要把 appSecret、token、cookie 发给任何人。需要展示配置时，只展示打码后的字段。

## 常见卡点

### GitHub 提示 Repository not found

通常是当前 GitHub 账号没有私有仓库权限。请管理员把你的 GitHub 账号加入 `Viy1204/pi-intern-agent-base`。

### spawn bash ENOENT

说明飞书 bridge 找不到 Git Bash。先确认：

```powershell
bash --version
```

如果失败，安装 Git for Windows，或把 `C:\Program Files\Git\usr\bin` 加到用户 PATH。改完后关闭并重新打开终端。

### No models available

说明 Pi 还没配置模型/API。启动 Pi 后先运行 `/login`。

### Skill conflicts 里有 skipped

这通常表示同名 skill 已经在用户目录存在，不是安装失败。优先看真正的 error 行。

## 部门 skill

部门 skill 不包含在通用基座里。需要部门能力时，额外安装对应部门包。
