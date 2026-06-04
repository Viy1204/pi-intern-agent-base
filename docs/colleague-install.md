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
pi install git:github.com/Viy1204/pi-intern-agent-base@v0.1.0
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
- 引导 `/feishu setup`
- 验证 `/feishu status`

## 飞书

飞书能力分两层：

- `lark-cli`：用于文档、日历、表格、IM 等飞书 API 操作
- `pi-intern-feishu-bridge`：用于在飞书里直接和 Pi 对话

不要把 appSecret、token、cookie 发给任何人。需要展示配置时，只展示打码后的字段。

## 部门 skill

部门 skill 不包含在通用基座里。需要部门能力时，额外安装对应部门包。
