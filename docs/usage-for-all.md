# Pi 实习生智能体使用说明

这是一份给全公司同事看的简版说明。你可以把 Pi 实习生理解成一个会用飞书和办公工具的 AI 助手。

## 你可以用它做什么

- 整理飞书文档、表格、会议纪要和待办。
- 查找、总结、改写、翻译办公资料。
- 帮你做日程、任务、知识库、多维表格等飞书操作。
- 在你确认后，帮你创建文档、写入表格、发送消息或更新任务。

## 第一次使用前

如果你的电脑还没有装过这些工具，请先安装或联系管理员协助安装：

1. Pi Agent 或公司指定的兼容客户端。
2. Git。
3. Node.js LTS。
4. Git Bash，Windows 用户通常安装 Git 时会一起安装。
5. `lark-cli`，用于连接飞书能力。

安装后打开终端，检查这些命令是否能正常显示版本：

```powershell
pi --version
git --version
node --version
npm --version
bash --version
lark-cli --version
```

如果有命令提示“不存在”或“无法识别”，把截图发给管理员处理。

## 缺工具时怎么安装

如果上面的检查命令有失败，优先按下面方式补装。装完后，请关闭并重新打开 Claude Code 或终端，再重新检查。

| 缺少工具 | Windows 安装命令 | 官网 / 说明 |
| --- | --- | --- |
| `winget` | 无一行命令，按 Microsoft 说明安装或修复 App Installer | https://learn.microsoft.com/windows/package-manager/winget/ |
| `git` | `winget install --id Git.Git -e --source winget` | https://git-scm.com/download/win |
| `node` / `npm` | `winget install --id OpenJS.NodeJS.LTS -e --source winget` | https://nodejs.org/en/download |
| `claude` | `npm install -g @anthropic-ai/claude-code` | https://docs.claude.com/en/docs/claude-code/setup |
| `pi` | `npm install -g @earendil-works/pi-coding-agent` | https://www.npmjs.com/package/@earendil-works/pi-coding-agent |
| `lark-cli` | `npx @larksuite/cli@latest install` | https://github.com/larksuite/cli |

`lark-cli` 安装后，还需要继续配置飞书：

```powershell
lark-cli config init --new
lark-cli auth login
```

## 安装 Pi 实习生基座

Claude Code 用的安装 skill 已经打包好，文件名是：

```text
pi-intern-base-installer.skill
```

这个文件在本文末尾附件里。下载后，把它安装到 Claude Code 的个人 skills 目录。

Windows 可以这样做：

```powershell
New-Item -ItemType Directory -Force "$HOME\.claude\skills"
Expand-Archive .\pi-intern-base-installer.skill -DestinationPath "$HOME\.claude\skills" -Force
```

安装后，重新打开 Claude Code，然后直接说：

```text
帮我安装 Pi 实习生通用基座
```

Claude Code 会调用 `pi-intern-base-installer` 这个 skill，帮你检查环境并安装通用基座。

如果你想确认 skill 文件结构，它在包里的位置是：

```text
pi-intern-base-installer/SKILL.md
```

如果你不想通过附件安装，也可以从 GitHub 拉取后复制 skill 目录：

```powershell
git clone https://github.com/Viy1204/pi-intern-agent-base.git
cd pi-intern-agent-base
Copy-Item -Recurse -Force .\claude\skills\pi-intern-base-installer "$HOME\.claude\skills\pi-intern-base-installer"
```

如果你不使用 Claude Code，也可以直接在终端安装：

确认你已经有 GitHub 私有仓库访问权限后，在终端执行：

```bash
pi install git:github.com/Viy1204/pi-intern-agent-base@v0.1.0
```

如果提示没有权限，请联系管理员把你加入仓库权限名单。

## 完成初始化

安装完成后，打开 Pi，对它说：

```text
使用 pi-intern-setup，帮我完成基座初始化
```

它会一步步检查环境，并引导你完成飞书配置。看到检查结果后，按它的提示继续即可。

第一次打开 Pi 时，如果还没有配置模型/API，请先输入：

```text
/login
```

按提示配置 API key、OAuth 或模型 provider。然后继续配置飞书插件：

```text
/feishu setup
/feishu status
```

如果 `/feishu setup` 后没有反应，先输入：

```text
/feishu restart
```

## 怎么提需求

尽量把“目标、材料、输出形式”说清楚。

可以这样说：

```text
帮我总结这个飞书文档，输出 5 条要点和 3 个待办。
```

```text
帮我把这份会议纪要整理成周报，语气正式一点。
```

```text
帮我查一下今天还有哪些未完成任务。
```

```text
帮我新建一个飞书文档，标题是「项目复盘」，先给我看大纲，确认后再写入。
```

## 重要提醒

- 不要把密码、验证码、token、appSecret、cookie 发给 Pi。
- 涉及写入、删除、移动、发消息、改权限等操作时，先确认再让它执行。
- 如果它要操作飞书，请先确认当前登录的是你自己的账号。
- 如果结果不符合预期，直接说“重新按这个格式来”，并给它一个例子。

## 常见问题

### 安装失败

先检查 GitHub 权限、网络、Git 是否正常。

如果提示 `Repository not found`，通常是当前 GitHub 账号还没有私有仓库权限。请联系管理员加入仓库。

如果弹出 GitHub 登录窗口后被取消，可以重新运行：

```powershell
git ls-remote https://github.com/Viy1204/pi-intern-agent-base.git HEAD
```

按提示登录后，再重新安装。

### 飞书操作失败

先执行初始化里的飞书配置。如果仍失败，把报错发给管理员，但不要发送 token、appSecret 或 cookie。

如果看到 `spawn bash ENOENT`，说明飞书插件找不到 Git Bash。安装 Git for Windows，或把 `C:\Program Files\Git\usr\bin` 加到用户 PATH，然后关闭并重新打开终端。

如果看到 `No models available`，说明还没配置模型/API，先运行 `/login`。

如果启动时看到很多 skill 的 `(skipped)`，通常只是同名 skill 已经存在，不代表安装失败。

### 不知道该怎么问

直接用自然语言说你的目标。比如“帮我整理这个文档”“帮我做一个表格”“帮我写一版通知”。Pi 会继续追问缺少的信息。
