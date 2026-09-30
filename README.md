# 上班聚宝盆 · 桌面悬浮球（开源共享版）

上班摸鱼情绪玩具：网页版设置攒钱目标，工时实时折算收益（每天 8 小时，自动扣除午休），macOS 桌面悬浮球实时显示「今日已赚」，数据与网页版实时同步。

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

### 2. 构建并运行桌面悬浮球（macOS）

```bash
cd app && ./build.sh   # 需要 Xcode Command Line Tools
open 上班聚宝盆悬浮球.app
```

菜单栏 💰 → **设置服务器地址**，填入你的网页版地址（如 `http://your-domain.com/float.html`）。

### 3. 使用

- 网页版：打开 `/`，添加目标 → 设置月薪与上班时间 → 开始攒钱
- 悬浮球：拖动移动，拖右下角缩放，单击切换置顶，悬停展开目标详情
- 数据自动双向同步（网页保存 → 服务器 → 悬浮球，3 秒内）

## 隐私说明

- 所有数据默认只存你自己的浏览器（localStorage）和你的服务器（data.json），不上传任何第三方
- 仓库不含任何真实用户数据；`data.json` 已被 .gitignore 排除
- 同步接口无鉴权，**请勿部署到公开可访问的服务器**（或自行加密码/鉴权），仅供个人使用

## 技术栈

- 网页：原生 HTML/CSS/JS 单文件（无任何依赖）
- 悬浮球：Swift + AppKit + WebKit（NSPanel 透明无边框窗口）
- 同步：Python http.server（零依赖）
