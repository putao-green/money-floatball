#!/bin/bash
# 构建 macOS 桌面悬浮球（需 Xcode Command Line Tools：xcode-select --install）
set -e
cd "$(dirname "$0")"

echo "编译中..."
swiftc -parse-as-library -swift-version 5 -O -framework Cocoa -framework WebKit FloatBall.swift -o FloatBall

echo "打包 .app..."
APP="上班聚宝盆悬浮球.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp FloatBall "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/Info.plist"
xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep -s - "$APP" >/dev/null 2>&1 || true

echo "完成：$APP"
echo "运行：open \"$APP\"，然后菜单栏 💰 → 设置服务器地址"
