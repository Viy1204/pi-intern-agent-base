# Pi 实习生智能体基座安装说明

## 适用对象

这份说明用于安装通用 Pi 实习生智能体基座。通用基座不包含任何部门专属 skill。

## 安装

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
