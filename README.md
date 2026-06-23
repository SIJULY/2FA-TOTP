# 2FA-TOTP 动态验证码获取工具

这是一个基于纯前端静态网页实现的 **2FA (TOTP) 动态验证码生成工具**。

用户可以输入从各个平台（如 Github、Google 等）获取的 2FA 秘钥（Base32 格式），工具会自动计算并显示 6 位数的实时动态验证码，默认每 30 秒刷新一次，方便用户进行账号登录验证。它完全可以作为网页版替代 Google Authenticator 等手机 App 的功能。

## ✨ 特性

- **纯前端实现**：无需后端服务器，基于 Vue.js 和 OTPAuth 在浏览器端实时计算，安全可靠。
- **一键复制**：点击下方按钮即可快速将生成的验证码复制到剪贴板。
- **参数灵活**：支持自定义验证码位数和刷新周期，也支持通过 URL 自动传递参数（如访问 `/?key=YOURKEY` 自动填入秘钥）。
- **极简部署**：提供一键安装脚本，全自动完成 Docker 容器部署和本地 Caddy 反向代理配置（全自动配置 HTTPS）。

---

## 🚀 一键安装指南

### 安装前提条件

1. 一台 Linux 服务器（VPS）。
2. 拥有 **root** 权限。
3. 一个已经**解析到该服务器 IP 的域名**（例如 `2fa.yourdomain.com`）。
   > *注：如果服务器没有安装 Caddy，安装脚本会自动为你检测并安装最新版的 Caddy。*

### 安装命令

登录到你的服务器，复制并执行以下命令即可全自动安装：

```bash
bash <(curl -s https://raw.githubusercontent.com/SIJULY/2FA-TOTP/main/install.sh)
```

**脚本执行流程：**
1. 自动检查并安装依赖环境（`git`、`docker`、`docker-compose`）。
2. 交互式提示你输入已解析的域名。
3. 拉取本仓库最新代码到 `/opt/2fa-totp` 目录。
4. 如果本机未安装 Caddy，脚本将根据你的系统（Debian/Ubuntu/CentOS等）自动安装 Caddy。
5. 使用 Docker 启动 Web 服务容器，并映射到本机的 `8011` 端口以防止端口冲突。
6. 自动将该域名的反代规则追加到宿主机的 `/etc/caddy/Caddyfile` 中。
7. 热重载/启动 Caddy，Caddy 会在后台自动为你申请 Let's Encrypt 的 HTTPS 证书。

等待脚本执行完毕后，直接在浏览器中访问你绑定的域名（如 `https://2fa.yourdomain.com`）即可畅快使用！

---

## 💡 界面使用说明

1. 在 **“秘钥”** 输入框中输入你的 2FA 秘钥（通常是一串 Base32 格式的字符）。
2. （可选）修改验证码位数（通常为 6 位）和令牌刷新周期（通常为 30 秒）。
3. 页面中心的动态彩虹文字会实时显示验证码，进度条显示该验证码的剩余有效时间。
4. 点击下方大图标按钮，即可一键复制验证码。

---

## ⚙️ 手动部署（高级）

如果你不想使用一键脚本，或者想使用 Nginx/宝塔等其他环境，可以通过 Docker Compose 手动部署：

```bash
# 1. 克隆代码
git clone https://github.com/SIJULY/2FA-TOTP.git
cd 2FA-TOTP

# 2. 启动容器 (映射在本地 8011 端口)
docker-compose up -d --build
```

然后自行在你的 Web 服务器（Nginx、Apache 等）中配置反向代理指向 `127.0.0.1:8011` 即可。