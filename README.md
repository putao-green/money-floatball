# 上班好搭子 · 桌面悬浮球

上班摸鱼情绪玩具：网页版设置攒钱目标，把上班的每一秒折算成钱（每天 8 小时，自动扣午休），macOS 桌面悬浮球实时显示「今日已赚」，数据与网页版实时同步。

![桌面悬浮球](screenshots/float-ball.jpg)

## 特性

1. **透明悬浮球**：无边框透明面板贴在桌面上，壁纸之上、窗口之下，不挡工作。
2. **今日已赚实时跳动**：月薪 ÷ 21.75 个工作日 ÷ 每天 8 小时，算出每秒身价，金币往下掉、数字实时在涨。
3. **拖动 / 缩放 / 置顶**：按住面板拖动，拖右下角缩放，单击切换置顶或回到桌面层。
4. **悬停展开目标**：鼠标移上去展开当前攒钱目标与进度，移开自动收起。
5. **网页版同源同口径**：网页管月薪、时间、欲望清单和成就墙，悬浮球纯展示，改完目标 3 秒内两端一致。
6. **数据在自己手里**：数据存在你自己的浏览器和服务器，同步接口带密钥鉴权，GitHub 上没有你的任何数据。

## 网页版

网页版负责一切配置与记录：月薪、上下班与午休时间、欲望清单、成就墙、自动快照。

![网页版](screenshots/web.jpg)

「工资与数据」设置弹窗，月薪、时间、午休、计薪天数都在这里改，改完实时重算每秒收益。

![工资与数据设置](screenshots/settings.jpg)

## 快速开始

### 1. 部署网页版与同步服务（Linux + nginx）

```bash
# 上传 web/ 与 server/ 到服务器，例如 /var/www/money-floatball/
# 安装 python3（如已安装可跳过）
sudo yum install -y python3   # CentOS / 阿里云

# 注册同步服务
sudo cp server/moneysync.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now moneysync

# nginx 站点配置（参考 server/money.conf，改域名与路径）
sudo cp server/money.conf /etc/nginx/conf.d/money.conf
sudo nginx -t && sudo systemctl reload nginx
```

验证：`curl http://你的域名/sync` 应返回 `{"rev":"...","data":null}`。

### 2. 构建并运行「上班好搭子」（macOS）

需要 macOS 12 或更高，以及 Xcode 命令行工具。

```bash
cd app && ./build.sh   # 需要 Xcode Command Line Tools
open 上班好搭子.app
```

首次打开，菜单栏 💰 → **设置服务器与密钥**，填入网页版地址（如 `http://your-domain.com/float.html`）与同步密钥（可留空，服务器配了 SYNC_KEY 才需要）。

自己编译的 App 没有 Apple 签名，如果双击提示「已损坏」或没反应，执行：

```bash
xattr -d com.apple.quarantine 上班好搭子.app
```

## 使用

| 操作 | 说明 |
|---|---|
| 移动位置 | 按住面板主体拖动 |
| 改大小 | 拖右下角缩放手柄 |
| 切换置顶 | 单击面板，或菜单栏 💰 的「固定 / 取消固定」 |
| 看目标进度 | 鼠标悬停展开（见下图） |
| 打开网页版 | 菜单栏 💰 → 打开网页版 |
| 换服务器 / 密钥 | 菜单栏 💰 → 设置服务器与密钥 |

![悬停展开目标](screenshots/float-expanded.jpg)

放大后的悬浮球，拖右下角可以任意缩放大小：

![放大后的悬浮球](screenshots/float-large.jpg)

## 数据隔离（重要）

多人共用同一份代码时，数据靠两层隔离：

1. **域名天然隔离**：不同人部署到不同域名，数据存在各自的 localStorage 和各自的服务器，互不干扰。
2. **单密钥鉴权**：服务端只认一个密钥，密钥通过环境变量注入（不进代码、不进仓库）。请求必须带请求头 `X-Sync-Key`，不匹配直接 403。每个人部署时各自设自己的密钥，天然互相隔离。

### 部署时怎么配密钥

- **服务端**（systemd）：`moneysync.service` 里 `Environment=SYNC_KEY=你的32位随机串`（可运行 `openssl rand -hex 16` 生成），改完 `systemctl daemon-reload && systemctl restart moneysync`
- **网页版**：打开「工资与数据」弹窗 → 数据同步 → 填同一个密钥（存 localStorage，不进代码）
- **悬浮球**：菜单栏 💰 → 设置服务器与密钥 → 填同一个密钥

> 密钥只在你自己的浏览器/悬浮球里，GitHub 代码里永远没有密钥值。密钥泄露等同于数据公开，请用 32 位以上随机串并保密。
> 未配置 `SYNC_KEY` 环境变量时服务端不做鉴权（兼容旧版，仅建议内网使用）。

## 隐私说明

- 所有数据默认只存你自己的浏览器（localStorage）和你的服务器（data.json），不上传任何第三方
- 仓库不含任何真实用户数据；`data.json` 已被 .gitignore 排除
- 同步接口用 `X-Sync-Key` 请求头鉴权；如需更高安全性（防懂技术的人抓包），请配置 HTTPS（nginx + 域名证书），并可在 nginx 层叠加 Basic Auth（`htpasswd` 生成密码文件，`auth_basic "Restricted"; auth_basic_user_file /etc/nginx/.htpasswd;`）

## 目录结构

```
money-floatball/
├── app/          # macOS 悬浮球（Swift 源码 + Info.plist + build.sh）
├── web/          # 网页版（index.html）与悬浮球页面（float.html）
├── server/       # 同步服务（sync.py）+ nginx/systemd 部署示例
├── screenshots/  # README 截图
└── README.md
```

## 技术栈

- 网页：原生 HTML/CSS/JS 单文件（无任何依赖）
- 悬浮球：Swift + AppKit + WebKit（NSPanel 透明无边框窗口）
- 同步：Python http.server（零依赖）

## 许可

[MIT License](LICENSE)
