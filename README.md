# Pi 实习生智能体

给你配一个**会用飞书的 AI 实习生**：装好之后，你在飞书里像跟同事聊天一样给它派活，它在你的电脑上把活干完。

它能做什么：读写飞书文档 / 表格 / 多维表格、查日历、发消息、整理云盘文件、做 Word / PPT / Excel / PDF，以及任何你能在电脑上做的事。

> 想了解「为什么这么设计」，看 [DESIGN.md](DESIGN.md)。

---

## 谁适合装

- 想要一个通用办公 AI 助手的同事
- 经常要处理飞书文档、表格、日历、消息的同事
- 之后还打算叠加部门专属能力（招聘、面试官等）的同事

## 安装（三步）

### 第一步：装好基础软件

打开 PowerShell，一条条运行下面的命令。已经装过的会提示已存在，跳过就行。

```powershell
winget install --id Git.Git -e --source winget
```

```powershell
winget install --id OpenJS.NodeJS.LTS -e --source winget
```

```powershell
npm install -g @earendil-works/pi-coding-agent
```

```powershell
npx @larksuite/cli@latest install
```

**装完请关掉 PowerShell 重新打开**（不然新装的命令找不到）。然后检查一下，四行都应该输出版本号：

```powershell
pi --version; git --version; node --version; lark-cli --version
```

有任何一行报错，去下面的[常见问题](#常见问题)找对应的那条。

### 第二步：装实习生

```powershell
pi install git:github.com/Viy1204/pi-intern-agent-base
```

### 第三步：让它自己配置自己

打开 Pi（终端里输入 `pi`），然后**直接用中文说**：

```text
使用 pi-intern-setup，帮我完成基座初始化
```

它会带着你走完剩下的配置：检查环境、写入行为规范、引导你登录模型、配置飞书。跟着提示走就行。

配置飞书的那一步会让你扫码创建飞书应用——扫码授权即可，不需要懂技术细节。

---

## 装完之后怎么用

### 在终端里用

输入 `pi` 打开，然后直接说话：

```text
帮我把这个季度的招聘数据整理成表格
```

### 在飞书里用（推荐）

配置完飞书后，**在飞书里私聊你的机器人**发一条消息——第一个私聊它的人自动成为它的主人（也就是你）。之后你在飞书里说的话它都会处理。

飞书里可用的命令：

| 命令 | 作用 |
|---|---|
| `/new` | 开个新话题，之前聊的内容不带过来 |
| `/stop` | 停掉正在跑的任务 |
| `/model` | 换一个 AI 模型 |
| `/resume` | 切回之前的某次对话 |
| `/workspace` | 查看或切换它默认在哪个文件夹干活 |

在终端 Pi 里管理飞书连接：

| 命令 | 作用 |
|---|---|
| `/feishu status` | 看现在连着没有 |
| `/feishu restart` | 重启连接（**配置改完或者没反应时先试这个**） |
| `/feishu stop` | 断开连接 |
| `/feishu setup` | 重新配置飞书 |

---

## 关于安全，你需要知道的三件事

**1. 只有你能用它。** 默认只有主人（第一个私聊它的人）和你明确允许的人能用，其他人发消息它完全不理（不回复也不提示，避免暴露它的存在）。

要放开给同事或某个群使用，编辑 `C:\Users\你的用户名\.pi\agent\feishu\config.json`，加上：

```json
{
  "allowedUsers": ["同事的open_id"],
  "allowedChats": ["群的chat_id"]
}
```

改完运行 `/feishu restart` 生效。

**2. 它能碰你电脑上的文件。** 它以你的身份运行，你能读写的它都能读写。`/workspace` 只是设定它默认在哪个文件夹干活，不是权限限制。所以：**不要让不信任的人用它**。

为了避免误伤，它拒绝把工作文件夹设成磁盘根目录、你的主目录、桌面、下载、系统目录——这些范围太大。建议给它一个专门的文件夹，比如 `C:\Users\你的用户名\pi-work\`。

**3. 别把凭证发给别人。** appSecret、token、cookie 这类东西不要截图外发。需要别人帮你排查时，只发打码后的内容。

---

## 常见问题

### `pi` 命令不存在

Node.js 没装好，或者装完没重开终端。先跑 `node --version` 确认 Node 正常，再重新装一次 pi，然后**关掉终端重新打开**。

### `spawn bash ENOENT`

飞书连接需要 Git Bash。装 Git for Windows 时勾选 Git Bash 即可。装完确认这条能输出版本号：

```powershell
bash --version
```

还是报错的话，把 `C:\Program Files\Git\usr\bin` 加到系统 PATH，然后重开终端。

### `No models available`

还没配 AI 模型。在 Pi 里运行 `/login`，按提示配置。

### 飞书配好了但机器人不回消息

按顺序试：

1. `/feishu restart`
2. `/feishu status` 看是不是 `已连接`
3. 确认你是主人——第一个私聊它的人才是主人。如果第一条私聊是别人发的，主人就成了他，你需要手动改配置里的 `ownerOpenId`
4. 群里要不要 @ 它取决于配置的 `groupPolicy`，私聊一定不需要

### 卡片按钮点了没反应 / 提示已失效

升级之后旧卡片会失效，重新发一次消息生成新卡片即可。

### 提示飞书权限不足

把报错里提到的权限名发给管理员开通，**不要发 token 或 appSecret**。

### 启动时看到某些 skill 显示 skipped

不是错误。说明同名 skill 你已经装过了，用的是你自己那份。只需要关注真正的 error。

---

## 叠加更多能力

基座是通用的，部门专属能力单独装。

**HR 能力包**（需要授权）：

```powershell
pi install git:github.com/Viy1204/pi-intern-hr-pack@v0.1.1
```

**AI 面试官**——让机器人用真人声音加入飞书视频会议做语音面试：

```powershell
pi install git:github.com/Viy1204/feishu-interview-agent
```

装完在飞书里说「让面试官进会议 123456789」即可。详见[该项目说明](https://github.com/Viy1204/feishu-interview-agent)。

---

## 给维护者

```powershell
npm test          # 类型检查 + 单元测试
npm run test:pack # 打包完整性（skill 清单、HR 黑名单）
```

CI 在 Windows / macOS / Ubuntu 三平台跑。发布前确认打包内容不含部门私有 skill、个人路径、任何凭证。

项目结构和设计取舍见 [DESIGN.md](DESIGN.md)。
