# Xboard Only 实操文档

这套文件用于在服务器上单独安装新版 Xboard，不安装 NPM。

## 包含文件

- `bootstrap-xboard.sh`
- `install-xboard.sh`
- `update-xboard.sh`
- `menu-xboard.sh`
- `xboard-common.sh`
- `xboard-extra.sh`
- `xboard-runtime.sh`
- `firewall.sh`

## 安装方式

本地执行：

```bash
bash install-xboard.sh --interactive
```

远程一键执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/huanfeng123/xboard-ao3-control/main/deploy/xboard-only/bootstrap-xboard.sh)
```

默认会从以下仓库拉取主控端部署源：

```text
https://github.com/huanfeng123/xboard-ao3-control
```

## 安装完成后会显示

- Xboard 对外端口
- Xboard 管理员邮箱
- Xboard 目录
- 配置文件路径
- Xboard 首页
- Xboard 管理面板地址
- 已尝试放行的端口

## 管理命令

安装完成后会写入快捷命令：

```bash
xbo
```

也可以直接执行：

```bash
bash menu-xboard.sh
```

## 菜单功能

- 安装 / 重新配置 Xboard
- 更新 Xboard
- 查看 Xboard 状态
- 查看访问信息
- 放行额外端口
- 重启 Xboard
- 启动 Xboard
- 查看 Xboard 日志

## 常用命令

查看状态：

```bash
sudo docker compose -f runtime/Xboard/compose.yaml ps
```

查看日志：

```bash
sudo docker compose -f runtime/Xboard/compose.yaml logs -f --tail=100
```
