# NPM Only 实操文档

这套文件用于在新服务器上安装 Nginx Proxy Manager，并配合新版 Xboard 的 `machine mode` 节点使用。

适用场景：

- 你有一台主控服务器，跑 Xboard 面板
- 你有一台或多台新服务器，跑 `xboard-node`
- 你希望节点通过 `域名 + NPM + TLS + WebSocket` 对外提供服务

---

## 一、把文件上传到网页目录

把当前 `npm-only` 目录里的这些文件上传到你的网站目录：

- `bootstrap-npm.sh`
- `install-npm.sh`
- `update-npm.sh`
- `menu-npm.sh`
- `npm-common.sh`
- `npm-extra.sh`
- `firewall.sh`

如果你打算用浏览器或 HTTP 一键安装，确保这些文件都能直接访问，例如：

```text
http://你的服务器IP/bootstrap-npm.sh
http://你的服务器IP/install-npm.sh
http://你的服务器IP/update-npm.sh
http://你的服务器IP/menu-npm.sh
http://你的服务器IP/npm-common.sh
http://你的服务器IP/npm-extra.sh
http://你的服务器IP/firewall.sh
```

---

## 二、在新服务器安装 NPM

### 方式 1：远程一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/huanfeng123/xboard-ao3-control/main/deploy/npm/bootstrap-npm.sh)
```

### 方式 2：本地执行

```bash
bash install-npm.sh --interactive
```

安装完成后，可用命令：

```bash
xbn
```

进入 NPM 管理菜单。

---

## 三、在新服务器安装 xboard-node

去 Xboard 后台先新增一台机器，拿到安装命令。

示例：

```bash
curl -fsSL https://你的面板域名/storage/xboard-node/install.sh | sudo bash -s -- --mode machine --panel 'https://你的面板域名' --token '你的token' --machine-id 1
```

安装完成后检查：

```bash
sudo systemctl status xboard-node
sudo /usr/local/bin/xbctl list
curl -fsSL http://127.0.0.1:65530/healthz
```

正常情况下：

- `xboard-node` 是 `active (running)`
- `xbctl list` 显示 `active`
- `healthz` 返回 `{"status":"ok"}`

注意：

- 这里只代表 `xboard-node` 主程序在线
- 不代表节点已经能用了
- 节点是否可用，还要看后面后台绑定和 NPM 转发是否正确

---

## 四、域名解析

把你的节点域名解析到新服务器公网 IP。

例如：

```text
ao3.ao3l.live -> 新服务器公网IP
```

---

## 五、NPM 反代怎么填

### 先查 Docker 访问宿主机地址

在新服务器执行：

```bash
ip -4 addr show docker0 | awk '/inet /{print $2}' | cut -d/ -f1
```

常见结果：

```bash
172.17.0.1
```

这个地址很重要。

因为 NPM 跑在 Docker 容器里：

- 容器里的 `127.0.0.1` 不是宿主机
- 所以 NPM 转发时，优先填写这个 `docker0` 地址

### 新建 Proxy Host

以 `VLESS + WS + TLS` 为例：

- Domain Names：`ao3.ao3l.live`
- Scheme：`http`
- Forward Hostname / IP：`172.17.0.1`
- Forward Port：`10089`
- Websockets Support：开启

SSL 页面：

- 申请 Let’s Encrypt
- 证书域名就是 `ao3.ao3l.live`

如果客户端最终访问端口不是 `443`，还要额外添加 HTTPS 映射端口。

例如客户端要访问：

```text
ao3.ao3l.live:7892
```

就必须在菜单中添加：

```text
7892 -> 443
```

在菜单里操作：

```text
6. 添加 NPM 额外 HTTPS 端口映射
```

---

## 六、Xboard 后台怎么填

以你当前跑通的这类配置为例：

- 节点地址：`ao3.ao3l.live`
- 连接端口：`7892`
- 服务端口：`10089`
- 安全性：`TLS`
- 传输协议：`WebSocket`
- 绑定服务器：选择新服务器对应的机器，例如 `SID:1`

### 这几个端口怎么理解

#### 1. 连接端口

这是客户端真正连接的端口。

例如：

```text
ao3.ao3l.live:7892
```

这里的 `7892` 就是连接端口。

#### 2. 服务端口

这是 `xboard-node` 在新服务器本机真正监听的端口。

例如：

```text
10089
```

也就是 NPM 最终要转发到的端口。

#### 3. NPM HTTPS 映射端口

这是让 NPM 在额外端口接收 HTTPS 请求。

例如：

```text
7892 -> 443
```

表示：

- 外部访问 `7892`
- 实际先进入 NPM 的 `443`
- 再由 NPM 转发到节点服务端口 `10089`

### 一条链路看懂

```text
客户端 -> ao3.ao3l.live:7892
7892 -> NPM:443
NPM -> 172.17.0.1:10089
xboard-node -> 实际处理节点流量
```

一句话记忆：

- 连接端口 = 给客户端用
- 服务端口 = 给 xboard-node 监听
- NPM 映射端口 = 让 NPM 在额外端口接收 HTTPS

---

## 七、常见问题排查

### 1. `xboard-node` 在线，但节点不能用

先看日志：

```bash
sudo journalctl -u xboard-node -n 50 --no-pager
```

如果看到：

```text
bind: address already in use
```

说明服务端口被占用了。

解决方法：

- 改 Xboard 后台的“服务端口”
- 或释放被占用端口

查询是谁占用端口：

```bash
sudo ss -ltnp | grep :端口号
sudo lsof -iTCP:端口号 -sTCP:LISTEN -n -P
```

### 2. 访问域名返回 `502`

例如：

```bash
curl -kI https://ao3.ao3l.live:7892
```

返回：

```text
HTTP/2 502
```

说明：

- 请求已经到了 NPM
- 但 NPM 转发到后端失败

重点检查：

- NPM 的 Forward Hostname/IP 是否填成了 `172.17.0.1`
- Forward Port 是否填成了“服务端口”
- WebSocket 是否开启

### 3. 访问域名返回 `404`

例如：

```bash
curl -kI https://ao3.ao3l.live:7892
```

返回：

```text
HTTP/2 404
```

一般说明：

- 域名
- NPM
- 后端服务

这一整条链路已经打通了。

这通常不是坏事，反而说明比 `502` 更接近成功。

因为你直接访问的是根路径 `/`，而 WebSocket 节点本来就不一定返回网页内容。

接下来主要检查：

- 客户端配置
- WebSocket Path
- SNI
- TLS 设置

### 4. 主控菜单里显示 `xboard-node 不存在`

这个很多人会误会。

如果你是在主控服务器执行 `xb` 菜单，菜单检查的是：

- 主控服务器本机有没有 `xboard-node` 服务

不是检查远程节点机。

所以：

- 主控机没装 `xboard-node`
- 菜单显示不存在

这是正常的，不影响远程节点使用。

---

## 八、推荐的新增节点顺序

每次新增新服务器节点，按这个顺序做：

1. 新服务器安装 NPM
2. 新服务器安装 `xboard-node machine mode`
3. 域名解析到新服务器 IP
4. NPM 中新建 Proxy Host，转发到 `docker0地址:服务端口`
5. 如果连接端口不是 443，添加 `NPM HTTPS 映射端口`
6. Xboard 后台新增节点，并绑定到这台机器
7. 检查日志确认节点启动成功

---

## 九、常用命令

查看 `xboard-node` 状态：

```bash
sudo systemctl status xboard-node
```

查看 `xboard-node` 日志：

```bash
sudo journalctl -u xboard-node -n 100 --no-pager
```

查看本机服务端口是否监听：

```bash
sudo ss -ltnp | grep :10089
```

查看 Docker 宿主机地址：

```bash
ip -4 addr show docker0 | awk '/inet /{print $2}' | cut -d/ -f1
```

测试域名入口：

```bash
curl -kI https://你的域名:连接端口
```
