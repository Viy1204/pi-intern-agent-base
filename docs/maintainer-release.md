# 维护与发布

## 通用基座

发布前检查：

```powershell
npm test
rg -n "appSecret|access_token|refresh_token|cookie|password" .
```

发布建议使用 tag：

```bash
git tag v0.1.1
git push origin v0.1.1
```

同事安装：

```bash
pi install git:github.com/Viy1204/pi-intern-agent-base@v0.1.1
```

## HR 包

HR 包放在独立私有仓库 `Viy1204/pi-intern-hr-pack`，只分享给有权限的同事。不要把 HR 包合并进通用基座。

HR 同事在安装通用基座后，再额外安装：

```bash
pi install git:github.com/Viy1204/pi-intern-hr-pack@v0.1.1
```
