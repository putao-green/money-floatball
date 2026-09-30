# 上班好搭子 · 桌面悬浮球（开源共享版）

上班摸鱼情绪玩具：网页版设置攒钱目标，工时实时折算收益（每天 8 小时，自动扣除午休），macOS 桌面悬浮球「上班好搭子」实时显示「今日已赚」，数据与网页版实时同步。

## 功能

- **网页版**（单文件 HTML）：目标管理、今日已赚实时计时、金币雨动画、本地存储 + 服务器同步
- **桌面悬浮球**（macOS）：透明无边框、聚宝盆图标、今日已赚实时显示、可拖动/缩放、悬停展开目标详情、单击切换置顶
- **数据同步**：网页保存时推送服务器 `/sync`，悬浮球每 3 秒轮询拉取，两端完全一致

## 目录结构

```
money-floatball/
├── app/          # macOS 悬浮球（Swift 源码 + Info.plist + build.sh）
├── web/          # 网页版（index.html）与悬浮球页面（float.html）
├── server/       # 同步服务（sync.py）+ nginx/systemd 部署示例
└── README.md
```

## 快速开始

### 1. 部署网页版与同步服务（服务器，Linux + nginx）

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

```bash
cd app && ./build.sh   # 需要 Xcode Command Line Tools
open 上班好搭子.app
```

菜单栏 💰 → **设置服务器地址**，填入你的网页版地址（如 `http://your-domain.com/float.html`）。

### 3. 使用

- 网页版：打开 `/`，添加目标 → 设置月薪与上班时间 → 开始攒钱
- 悬浮球：拖动移动，拖右下角缩放，单击切换置顶，悬停展开目标详情
- 数据自动双向同步（网页保存 → 服务器 → 悬浮球，3 秒内）

## 数据隔离（重要）

多人共用同一份代码时，数据靠两层隔离：

1. **域名天然隔离**：不同人部署到不同域名，数据存在各自的 localStorage 和各自的服务器，互不干扰。
2. **key 隔离**：`web/index.html` 和 `web/float.html` 顶部各有一行 `SYNC_KEY` 配置。填一段随机串（如 `k7x9m2q...`）后，数据会存到服务端 `data_<key>.json`，不带 key 的人读不到也改不了你的数据；留空则存 `data.json`（兼容旧版）。

> 换 key 时注意：旧数据在 `data.json` 里，浏览器 localStorage 会作为权威数据自动推送到新 key 文件，一般无需手动迁移；也可以直接 `cp data.json data_<新key>.json`。

> key 写在网页代码里，对普通访问者是有效的隔离/防篡改凭据；要彻底防住懂技术的人，请在 nginx 层叠加 Basic Auth（见下）。

## 隐私说明

- 所有数据默认只存你自己的浏览器（localStorage）和你的服务器（data.json / data_<key>.json），不上传任何第三方
- 仓库不含任何真实用户数据；`data*.json` 已被 .gitignore 排除
- 同步接口依赖 key 隔离，**如需更高安全性**，在 nginx 站点配置加 Basic Auth（`htpasswd` 生成密码文件，`auth_basic "Restricted"; auth_basic_user_file /etc/nginx/.htpasswd;`），网页与悬浮球访问都会要求密码

## 技术栈

- 网页：原生 HTML/CSS/JS 单文件（无任何依赖）
- 悬浮球：Swift + AppKit + WebKit（NSPanel 透明无边框窗口）
- 同步：Python http.server（零依赖）
