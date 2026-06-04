# Pi Intern Agent Base

Pi 实习生智能体通用基座。它提供通用办公 skill、飞书/Lark skill、飞书通信 bridge，以及一份可选安装的通用 `AGENTS.md` 行为规范。

通用基座不包含 HR 专属 skill，也不包含个人路径、个人 open_id、token、appSecret、cookie 或部门私有规则。

## 适合谁安装

- 需要一个通用办公实习生智能体的同事。
- 需要在 Pi 里使用飞书文档、表格、日历、IM、任务、知识库等能力的同事。
- 后续还要叠加部门 skill 包的同事。

## 新电脑先安装这些

如果同事电脑上还没有任何 agent 或开发工具，建议按这个顺序准备：

1. 安装 Pi Agent 或支持 Pi package/skill 的兼容客户端。
2. 安装 Git。
3. 安装 Node.js LTS，建议 Node.js 20 或更高版本。
4. 安装 Git Bash。Windows 安装 Git for Windows 时通常会一起安装。
5. 确认自己有这个 GitHub 私有仓库的访问权限。
6. 如需使用飞书能力，安装并配置 `lark-cli`。

在终端里检查：

```powershell
pi --version
git --version
node --version
npm --version
bash --version
lark-cli --version
```

如果 `lark-cli --version` 暂时失败，也可以先安装基座，之后在初始化流程里继续处理飞书配置。

## 安装基座

```bash
pi install git:github.com/Viy1204/pi-intern-agent-base@v0.1.0
```

私有仓库需要先确认安装者已经被加入 GitHub 仓库权限。

## 初始化

安装完成后，打开 Pi，对它说：

```text
使用 pi-intern-setup，帮我完成基座初始化
```

初始化会引导完成：

- 检查 Pi、Node.js、npm、Git、Git Bash、`lark-cli`。
- 询问是否安装通用 `AGENTS.md`。
- 默认把通用行为规范写入当前工作区 `.pi/AGENTS.md`。
- 如选择全局写入 `~/.pi/agent/AGENTS.md`，会先备份已有文件。
- 引导 `/feishu setup` 和 `/feishu status`。

## 飞书能力

飞书能力分两层：

- `lark-cli`：用于飞书文档、表格、多维表格、日历、IM、任务、知识库等 API 操作。
- `pi-intern-feishu-bridge`：用于在飞书里直接和 Pi 对话。

不要把 appSecret、token、cookie、个人 open_id 发给别人。需要排查配置时，只展示打码后的字段。

## 部门 skill 包

部门能力不放在通用基座里。需要部门能力时，先安装本基座，再额外安装对应部门包。

HR 授权同事可额外安装：

```bash
pi install git:github.com/Viy1204/pi-intern-hr-pack@v0.1.0
```

## 常见问题

### pi 命令不存在

说明还没有安装 Pi Agent/CLI，或安装后没有加入系统 PATH。先安装 Pi，再重新打开终端检查 `pi --version`。

### git 命令不存在

安装 Git。Windows 建议安装 Git for Windows，并确认安装 Git Bash。

### node 或 npm 命令不存在

安装 Node.js LTS。安装后重新打开终端，再检查 `node --version` 和 `npm --version`。

### 没有 GitHub 权限

请仓库管理员把同事加入私有仓库访问名单。没有权限时，`pi install git:...` 会拉取失败。

### 飞书权限不足

先执行初始化流程里的 `/feishu setup`。如果仍然失败，把报错中的缺失 scope 或权限点发给管理员，不要发送 token 或 appSecret。

## 维护者检查

发布前至少执行：

```powershell
npm test
npm audit --audit-level=high
npm pack --dry-run
```

并确认打包内容不包含部门私有 skill、个人路径、token、appSecret、cookie。
