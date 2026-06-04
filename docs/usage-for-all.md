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

### 飞书操作失败

先执行初始化里的飞书配置。如果仍失败，把报错发给管理员，但不要发送 token、appSecret 或 cookie。

### 不知道该怎么问

直接用自然语言说你的目标。比如“帮我整理这个文档”“帮我做一个表格”“帮我写一版通知”。Pi 会继续追问缺少的信息。
