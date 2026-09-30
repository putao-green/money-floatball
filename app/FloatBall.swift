import Cocoa
import WebKit
import CoreGraphics

@main
class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    var panel: NSPanel!
    var webView: WKWebView!
    var catchView: CatchView!
    var statusItem: NSStatusItem!
    var baseURL: String {
        D.string(forKey: "baseURL") ?? "http://YOUR-SERVER-ADDRESS/float.html"
    }
    var syncKey: String {
        D.string(forKey: "syncKey") ?? ""
    }

    // 持久化
    let D = UserDefaults.standard
    var pinned: Bool = true

    func applicationDidFinishLaunching(_ n: Notification) {
        pinned = D.object(forKey: "pinned") as? Bool ?? true

        // 面板：无边框 + 可调整大小 + 非激活 + 透明
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 280, height: 400),
                        styleMask: [.borderless, .resizable, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 200, height: 260)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        applyLevel()

        // WebView
        let cfg = WKWebViewConfiguration()
        webView = WKWebView(frame: panel.contentView!.bounds, configuration: cfg)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self
        panel.contentView?.addSubview(webView)

        // 点击/悬停拦截层
        catchView = CatchView(frame: panel.contentView!.bounds)
        catchView.autoresizingMask = [.width, .height]
        catchView.onClick = { [weak self] in self?.togglePin() }
        catchView.onEnter = { [weak self] in self?.setExpanded(true) }
        catchView.onExit = { [weak self] in self?.setExpanded(false) }
        panel.contentView?.addSubview(catchView, positioned: .above, relativeTo: webView)

        // 恢复位置与大小
        let scr = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let px = D.object(forKey: "px") as? CGFloat ?? (scr.maxX - 300)
        let py = D.object(forKey: "py") as? CGFloat ?? (scr.maxY - 420)
        let pw = D.object(forKey: "pw") as? CGFloat ?? 280
        let ph = D.object(forKey: "ph") as? CGFloat ?? 400
        panel.setFrame(NSRect(x: px, y: py, width: pw, height: ph), display: true)

        panel.makeKeyAndOrderFront(nil)
        NotificationCenter.default.addObserver(self, selector: #selector(winMoved), name: NSWindow.didMoveNotification, object: panel)
        NotificationCenter.default.addObserver(self, selector: #selector(winResized), name: NSWindow.didResizeNotification, object: panel)

        setupStatusItem()
        loadPage()
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - 页面加载
    func loadPage() {
        catchView.isHidden = false
        if baseURL.contains("YOUR-SERVER-ADDRESS") {
            let html = "<html><body style='font-family:-apple-system;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;color:#54372E;text-align:center;font-size:13px'><div>请先设置服务器地址：<br>菜单栏 💰 → 设置服务器地址</div></body></html>"
            webView.loadHTMLString(html, baseURL: nil)
            return
        }
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let url = URL(string: baseURL + "?_ts=" + String(ts))!
        // 注入同步密钥到页面 localStorage（同源），float.html 读取后随 /sync 请求带上 X-Sync-Key
        let esc = syncKey.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        let js = "try{localStorage.setItem('wb_sync_key','" + esc + "')}catch(e){}"
        let us = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        webView.configuration.userContentController.removeAllUserScripts()
        webView.configuration.userContentController.addUserScript(us)
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        setExpanded(false)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showFallback()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showFallback()
    }

    func showFallback() {
        catchView.isHidden = true
        let html = """
        <html><head><meta charset="utf-8"><style>
        body{font-family:-apple-system,'PingFang SC',sans-serif;background:transparent;color:#54372E;
        display:flex;align-items:center;justify-content:center;height:100vh;margin:0;text-align:center}
        .box{background:rgba(255,253,248,.92);border-radius:14px;padding:20px 24px;box-shadow:0 6px 20px rgba(120,70,20,.15)}
        p{margin:6px 0;font-size:13px}.btn{margin-top:12px;padding:8px 22px;border:none;border-radius:10px;
        background:#F6B900;color:#6B4400;font-weight:700;font-size:14px;cursor:pointer}
        </style></head><body>
        <div class="box"><p>加载失败</p><p>请确认已上传 float.html 到服务器</p>
        <button class="btn" onclick="location.reload()">重试</button></div>
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - 悬停展开 / 收起（交给页面控制 .expanded）
    func setExpanded(_ on: Bool) {
        catchView.expanding = on
        if on {
            catchView.cancelPending()
            webView.evaluateJavaScript("document.querySelector('.float-card').classList.add('expanded')", completionHandler: nil)
        } else {
            catchView.cancelPending()
            catchView.pending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self = self, self.catchView.pending else { return }
                self.catchView.pending = false
                self.webView.evaluateJavaScript("document.querySelector('.float-card').classList.remove('expanded')", completionHandler: nil)
            }
        }
    }

    // MARK: - 置顶切换
    @objc func togglePin() {
        pinned.toggle()
        D.set(pinned, forKey: "pinned")
        applyLevel()
        updateMenu()
    }

    func applyLevel() {
        if pinned {
            panel.level = .floating
        } else {
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        }
    }

    // MARK: - 位置 / 大小持久化
    @objc func winMoved() {
        D.set(panel.frame.origin.x, forKey: "px")
        D.set(panel.frame.origin.y, forKey: "py")
    }

    @objc func winResized() {
        D.set(panel.frame.size.width, forKey: "pw")
        D.set(panel.frame.size.height, forKey: "ph")
    }

    // MARK: - 菜单栏
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let b = statusItem.button {
            b.title = "💰"
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        let m = NSMenu()
        let open = NSMenuItem(title: "打开网页版", action: #selector(openWeb), keyEquivalent: "")
        open.target = self
        m.addItem(open)
        let pin = NSMenuItem(title: "", action: #selector(togglePin), keyEquivalent: "")
        pin.target = self
        m.addItem(pin)
        let set = NSMenuItem(title: "设置服务器与密钥", action: #selector(setServer), keyEquivalent: "")
        set.target = self
        m.addItem(set)
        m.addItem(NSMenuItem(title: "重新加载", action: #selector(reload), keyEquivalent: "r"))
        m.addItem(NSMenuItem(title: "重置位置", action: #selector(resetPos), keyEquivalent: ""))
        m.addItem(NSMenuItem.separator())
        m.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        for it in m.items { it.target = self }
        statusItem.menu = m
        updateMenu()
    }

    @objc func setServer() {
        let alert = NSAlert()
        alert.messageText = "设置服务器与密钥"
        alert.informativeText = "服务器地址：网页版部署地址，例如 http://your-server.com/float.html\n同步密钥：与网页「工资与数据」弹窗里填的同步密钥一致（服务器配了 SYNC_KEY 才需要）"
        let box = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 64))
        let f1 = NSTextField(frame: NSRect(x: 0, y: 38, width: 340, height: 24))
        f1.stringValue = baseURL
        let f2 = NSTextField(frame: NSRect(x: 0, y: 8, width: 340, height: 24))
        f2.stringValue = syncKey
        f2.placeholderString = "同步密钥（可留空）"
        box.addSubview(f1)
        box.addSubview(f2)
        alert.accessoryView = box
        alert.addButton(withTitle: "保存并加载")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            var v = f1.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let k = f2.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty {
                // 自动补全悬浮球页面路径：填根域名或 / 结尾时补 /float.html
                if !v.contains("float.html") {
                    if v.hasSuffix("/") { v += "float.html" } else { v += "/float.html" }
                }
                D.set(v, forKey: "baseURL")
                D.set(k, forKey: "syncKey")
                loadPage()
            }
        }
    }

    func updateMenu() {
        if let m = statusItem.menu, m.items.count > 1 {
            m.items[1].title = pinned ? "取消固定（桌面层）" : "固定（置顶）"
        }
    }

    @objc func openWeb() {
        let b = baseURL
        let root = b.replacingOccurrences(of: "/float.html", with: "/")
        if let u = URL(string: root) {
            NSWorkspace.shared.open(u)
        }
    }

    @objc func reload() {
        loadPage()
    }

    @objc func resetPos() {
        let scr = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        panel.setFrameOrigin(NSPoint(x: scr.maxX - panel.frame.width - 20, y: scr.maxY - panel.frame.height - 60))
        winMoved()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

// 点击 + 悬停拦截层
class CatchView: NSView {
    var onClick: (() -> Void)?
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?
    var pending = false
    var expanding = false
    var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(t)
        tracking = t
        super.updateTrackingAreas()
    }

    var dragStart = NSPoint.zero
    var winStart = NSRect.zero
    var mode = 0 // 0 none, 1 move, 2 resize
    let resizeZone: CGFloat = 26
    let minW: CGFloat = 200, minH: CGFloat = 260

    func isResizeZone(_ p: NSPoint) -> Bool {
        p.x >= bounds.width - resizeZone || p.y <= resizeZone
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        dragStart = event.locationInWindow
        winStart = window!.frame
        mode = isResizeZone(p) ? 2 : 1
        if mode == 2 { NSCursor.resizeUpDown.set() }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let w = window, mode != 0 else { return }
        let p = event.locationInWindow
        if mode == 1 {
            let dx = p.x - dragStart.x, dy = p.y - dragStart.y
            w.setFrameOrigin(NSPoint(x: winStart.origin.x + dx, y: winStart.origin.y + dy))
        } else {
            let nw = max(minW, winStart.width + (p.x - dragStart.x))
            let nh = max(minH, winStart.height - (p.y - dragStart.y))
            w.setFrame(NSRect(x: winStart.origin.x,
                              y: winStart.origin.y + winStart.height - nh,
                              width: nw, height: nh), display: true)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let p = event.locationInWindow
        let dist = hypot(p.x - dragStart.x, p.y - dragStart.y)
        if mode == 1 && dist < 4 { onClick?() }
        mode = 0
        NSCursor.arrow.set()
    }

    override func mouseEntered(with event: NSEvent) {
        onEnter?()
    }

    override func mouseExited(with event: NSEvent) {
        onExit?()
    }

    func cancelPending() {
        pending = false
    }
}
