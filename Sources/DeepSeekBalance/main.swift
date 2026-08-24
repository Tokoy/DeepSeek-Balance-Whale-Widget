import AppKit
import Foundation
import ServiceManagement

// MARK: - Config

enum Config {
    static var configDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".deepseek-balance", isDirectory: true)
    }
    static var configFile: URL { configDir.appendingPathComponent("config.json") }

    static func load() -> (apiKey: String?, mode: String, whalePos: String?, apiBase: String?, usage: [String: Any]?) {
        var apiKey: String?
        var mode = "time"
        var whalePos: String?
        var apiBase: String?
        var usage: [String: Any]?
        if let data = try? Data(contentsOf: configFile),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let k = obj["apiKey"] as? String, !k.isEmpty { apiKey = k }
            if let m = obj["mode"] as? String, m == "balance" { mode = m }
            if let p = obj["whalePos"] as? String { whalePos = p }
            if let a = obj["apiBase"] as? String, !a.isEmpty { apiBase = a }
            if let u = obj["usage"] as? [String: Any] { usage = u }
        }
        if apiKey == nil,
           let env = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"],
           !env.isEmpty {
            apiKey = env
        }
        return (apiKey, mode, whalePos, apiBase, usage)
    }

    static func save(apiKey: String? = nil, mode: String? = nil, whalePos: String? = nil, apiBase: String? = nil, usage: [String: Any]? = nil) {
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        var obj: [String: Any] = [:]
        if let data = try? Data(contentsOf: configFile),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            obj = existing
        }
        if let apiKey { obj["apiKey"] = apiKey }
        if let mode { obj["mode"] = mode }
        if let whalePos { obj["whalePos"] = whalePos }
        if let apiBase { obj["apiBase"] = apiBase }
        if let usage { obj["usage"] = usage }
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]) {
            try? data.write(to: configFile)
        }
    }
}

// MARK: - Balance API

struct BalanceInfo: Decodable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String
    let toppedUpBalance: String

    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }
}

struct BalanceResponse: Decodable {
    let isAvailable: Bool
    let balanceInfos: [BalanceInfo]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

// MARK: - Whale Floating Window

final class BubbleView: NSView {
    private let line1 = NSTextField(labelWithString: "")
    private let line2 = NSTextField(labelWithString: "")
    private let ink = NSColor(calibratedRed: 0x20 / 255.0, green: 0x31 / 255.0, blue: 0x70 / 255.0, alpha: 1)

    // 气泡加宽到 160（余额文字能完整显示），高 70 保持圆润；下方思考泡泡链间距均匀
    private let bubbleRect = NSRect(x: 44, y: 168, width: 160, height: 70)

    override init(frame: NSRect) {
        super.init(frame: frame)
        for label in [line1, line2] {
            label.textColor = ink
            label.alignment = .center
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            addSubview(label)
        }
        setTop("", size: 15)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 单行内容（时间大号）：居中
    func setTop(_ s: String, size: CGFloat) {
        line1.stringValue = s
        line1.textColor = ink
        line1.font = .monospacedDigitSystemFont(ofSize: size, weight: .semibold)
        line2.isHidden = true
        line1.frame = NSRect(x: 48, y: 191, width: 152, height: 24)
        needsDisplay = true
    }

    /// 两行内容（余额 + 今日已用）：标题行略大，副行小字
    func setTopBottom(_ top: String, _ bottom: String) {
        line1.stringValue = top
        line1.textColor = ink
        line1.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        line2.isHidden = false
        line2.stringValue = bottom
        line2.textColor = ink
        line2.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        line1.frame = NSRect(x: 48, y: 202, width: 152, height: 18)
        line2.frame = NSRect(x: 48, y: 185, width: 152, height: 15)
        needsDisplay = true
    }

    /// 台词模式：上行淡色「已思考(用时3 秒)」DeepSeek 人设，下行俏皮话
    func setThought(_ line: String) {
        line1.stringValue = "已思考(用时3 秒)"
        line1.textColor = NSColor(calibratedWhite: 0.45, alpha: 1)
        line1.font = .systemFont(ofSize: 9, weight: .regular)
        line2.isHidden = false
        line2.stringValue = line
        line2.textColor = ink
        line2.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        line1.frame = NSRect(x: 48, y: 201, width: 152, height: 13)
        line2.frame = NSRect(x: 48, y: 186, width: 152, height: 16)
        needsDisplay = true
    }

    /// 点击命中：气泡 + 两个思考小泡泡
    func contains(_ p: NSPoint) -> Bool {
        if bubbleRect.insetBy(dx: -4, dy: -4).contains(p) { return true }
        if p.x >= 126 && p.x <= 146 && p.y >= 147 && p.y <= 166 { return true }  // 泡泡1
        if p.x >= 128 && p.x <= 142 && p.y >= 133 && p.y <= 147 { return true }  // 泡泡2
        return false
    }

    /// 白底圆角气泡 + 思考泡泡链（大→小，间距均匀），深蓝描边 #203170
    override func draw(_ dirtyRect: NSRect) {
        let bubble = NSBezierPath(roundedRect: bubbleRect, xRadius: 26, yRadius: 26)
        let p1 = NSBezierPath(ovalIn: NSRect(x: 127.5, y: 149, width: 15, height: 15))
        let p2 = NSBezierPath(ovalIn: NSRect(x: 130, y: 135, width: 10, height: 10))

        NSColor.white.setFill()
        for path in [bubble, p1, p2] {
            path.fill()
        }
        ink.setStroke()
        for path in [bubble, p1, p2] {
            path.lineWidth = 2.5
            path.stroke()
        }
    }
}

final class WhaleView: NSView {
    private let imageView = NSImageView()
    private let bubble = BubbleView()

    var onClick: (() -> Void)?   // 点击鲸鱼或气泡：随机台词
    var onDragEnd: (() -> Void)?
    private var dragStart: NSPoint?
    private var windowOrigin: NSPoint?
    private var dragged = false

    // 眨眼：运行时生成闭眼帧，睁/闭帧切换（3~7 秒随机眨一次）
    private var openImage: NSImage?
    private var closedImage: NSImage?
    private var blinkTimer: Timer?
    private var nextBlinkAt = Date()

    override init(frame: NSRect) {
        super.init(frame: frame)
        if let img = NSImage(contentsOfFile: Self.whaleImagePath()) {
            imageView.image = img
            openImage = img
        }
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        addSubview(bubble)          // 气泡在下层
        addSubview(imageView)       // 鲸鱼在上层
        layoutSubviews()
        startBlink()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { blinkTimer?.invalidate() }

    /// 生成闭眼帧：把两只眼睛区域用采样肤色椭圆盖住（眉毛保留）
    private static func makeClosedEyes(from image: NSImage) -> NSImage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = cg.width, h = cg.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        // 眼睛区域（原图像素坐标，左上原点）：避开眉毛；CGContext 需 y 翻转
        let eyes: [(CGRect, CGColor)] = [
            (CGRect(x: 258, y: 344, width: 54, height: 30), CGColor(red: 248/255.0, green: 245/255.0, blue: 242/255.0, alpha: 1)),
            (CGRect(x: 362, y: 348, width: 46, height: 36), CGColor(red: 250/255.0, green: 243/255.0, blue: 242/255.0, alpha: 1)),
        ]
        for (r, color) in eyes {
            let flipped = CGRect(x: r.minX, y: CGFloat(h) - r.maxY, width: r.width, height: r.height)
            ctx.setFillColor(color)
            ctx.fillEllipse(in: flipped)
        }
        guard let out = ctx.makeImage() else { return nil }
        return NSImage(cgImage: out, size: image.size)
    }

    /// 眨眼调度：每 0.5s 检查一次，到点就眨（闭 0.12s 恢复）
    private func startBlink() {
        guard closedImage == nil, let open = imageView.image else { return }
        closedImage = Self.makeClosedEyes(from: open)
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            if now >= self.nextBlinkAt {
                self.performBlink()
                self.nextBlinkAt = now.addingTimeInterval(TimeInterval(3 + Int.random(in: 0...4)))
            }
        }
        RunLoop.main.add(t, forMode: .common)
        blinkTimer = t
        nextBlinkAt = Date().addingTimeInterval(1.5)
    }

    private func performBlink() {
        guard let closed = closedImage else { return }
        imageView.image = closed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            if let open = self?.openImage {
                self?.imageView.image = open
            }
        }
    }

    private static func whaleImagePath() -> String {
        if let url = Bundle.main.url(forResource: "whale", withExtension: "png") {
            return url.path
        }
        // 开发兜底：源码目录 assets/whale.png
        let src = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return src.appendingPathComponent("assets/whale.png").path
    }

    private func layoutSubviews() {
        // 角色居中偏下，气泡在左上方（思考泡构图）
        imageView.frame = NSRect(x: 90, y: 10, width: 140, height: 140)
    }

    override func layout() {
        super.layout()
        layoutSubviews()
    }

    func updateLines(_ top: String, _ bottom: String, topSize: CGFloat, isPhrase: Bool = false) {
        if isPhrase {
            bubble.setThought(top)
        } else if bottom.isEmpty {
            bubble.setTop(top, size: topSize)
        } else {
            bubble.setTopBottom(top, bottom)
        }
    }

    /// 只把落在鲸鱼 / 气泡（含尾巴、思考小泡泡）上的点击交给自身，其余透明区域穿透
    override func hitTest(_ point: NSPoint) -> NSView? {
        if imageView.frame.contains(point) || bubble.contains(point) {
            return self
        }
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
        windowOrigin = window?.frame.origin
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let origin = windowOrigin, let win = window else { return }
        let cur = event.locationInWindow
        let dx = cur.x - start.x
        let dy = cur.y - start.y
        if abs(dx) > 3 || abs(dy) > 3 { dragged = true }
        // 拖动：1:1 跟手，不做任何动画，避免抖动
        win.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if dragged {
            onDragEnd?()
            dragStart = nil
            windowOrigin = nil
            return
        }
        // 点击（角色或气泡）：Q 弹一下 + 随机台词
        bounceWhale()
        onClick?()
        dragStart = nil
        windowOrigin = nil
    }

    /// 按压 Q 弹：底部坐标基本不动，快速缩放回弹（玩偶质感）
    private func bounceWhale() {
        guard let layer = imageView.layer else { return }
        let origAnchor = layer.anchorPoint
        let origPosition = layer.position
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.15)
        layer.position = CGPoint(x: imageView.frame.midX,
                                 y: imageView.frame.minY + imageView.frame.height * 0.15)
        let anim = CAKeyframeAnimation(keyPath: "transform.scale")
        anim.values = [1.0, 0.86, 1.08, 0.95, 1.02, 1.0]
        anim.keyTimes = [0, 0.18, 0.4, 0.6, 0.8, 1.0]
        anim.duration = 0.5
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            layer.anchorPoint = origAnchor
            layer.position = origPosition
        }
        layer.add(anim, forKey: "bounce")
        CATransaction.commit()
    }
}

final class WhaleWindowController {
    let window: NSWindow
    private let whaleView: WhaleView

    init(onClick: @escaping () -> Void, onDragEnd: @escaping () -> Void) {
        let contentW: CGFloat = 300
        let contentH: CGFloat = 260
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: contentW, height: contentH),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        whaleView = WhaleView(frame: NSRect(x: 0, y: 0, width: contentW, height: contentH))
        whaleView.onClick = onClick
        whaleView.onDragEnd = onDragEnd
        window.contentView = whaleView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.alphaValue = 1.0
    }

    func show(at pos: String?) {
        if let pos, !pos.isEmpty {
            let parts = pos.split(separator: ",")
            if parts.count == 2, let x = Double(parts[0]), let y = Double(parts[1]) {
                window.setFrameOrigin(NSPoint(x: x, y: y))
            } else {
                placeAtDefault()
            }
        } else {
            placeAtDefault()
        }
        NSLog("[whale] showing at \(window.frame.origin)")
        window.orderFrontRegardless()
        NSLog("[whale] isVisible=\(window.isVisible)")
    }

    func placeAtDefault() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let f = window.frame
        window.setFrameOrigin(NSPoint(x: vf.maxX - f.width - 40, y: vf.minY + 40))
    }

    func updateLines(_ top: String, _ bottom: String, topSize: CGFloat, isPhrase: Bool = false) {
        whaleView.updateLines(top, bottom, topSize: topSize, isPhrase: isPhrase)
    }
    func savePosition() {
        let f = window.frame
        Config.save(whalePos: "\(Int(f.origin.x)),\(Int(f.origin.y))")
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var whale: WhaleWindowController?

    private var apiKey: String?
    private var apiBase: String?
    private var mode = "time"
    private var balance: BalanceResponse?
    private var lastError: String?
    private var lastUpdate: Date?
    private var isFetching = false

    // 今日已用（本地记账：余额差值累计，跨天归零）
    private var usageDate = ""
    private var usageAmount: Double = 0
    private var lastObserved: Double?
    private var usageCurrency = ""

    // 随机台词（点击触发）：台词 3 秒 → 余额展示 5 秒 → 恢复模式显示
    private var phrase: String?
    private var phraseUntil: Date?
    private var peekUntil: Date?
    private let catchphrases = [
        "今天也要加油鸭！",
        "大肥鲸驾到，通通闪开！",
        "快充钱！我想吃小鱼干～",
        "主人，摸摸头嘛～",
        "今日份可爱已送达！",
        "呜呜…余额在缩水…",
        "盯——你看我干嘛？",
        "摸鱼时间到！（嘘）",
        "工作使我快乐…才怪！",
        "我是鲸鱼，不是气球啦！",
        "余额满满才安心呀～",
        "呼噜呼噜…我睡着了（假的）",
    ]

    private var clockTimer: Timer?
    private var fetchTimer: Timer?

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    private let timeDetailFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let loaded = Config.load()
        apiKey = loaded.apiKey
        apiBase = loaded.apiBase
        mode = loaded.mode
        if let u = loaded.usage {
            usageDate = u["date"] as? String ?? ""
            usageAmount = u["amount"] as? Double ?? 0
            lastObserved = (u["lastObserved"] as? Double).flatMap { $0 >= 0 ? $0 : nil }
            usageCurrency = u["currency"] as? String ?? ""
        }

        configureStatusButton()
        setupWhaleWindow(pos: loaded.whalePos)
        startTimers()

        if apiKey == nil {
            promptForAPIKey()
        } else {
            fetchBalance()
        }
        refreshDisplay()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupWhaleWindow(pos: String?) {
        let controller = WhaleWindowController(
            onClick: { [weak self] in self?.bubbleClicked() },
            onDragEnd: { [weak self] in self?.whale?.savePosition() })
        whale = controller
        controller.show(at: pos)
    }

    private func startTimers() {
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshDisplay()
        }
        fetchTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.fetchBalance()
        }
        [clockTimer, fetchTimer].compactMap { $0 }.forEach {
            RunLoop.main.add($0, forMode: .common)
        }
    }

    // MARK: Display

    private var displayText: String {
        if mode == "balance" {
            if let b = balance, let first = b.balanceInfos.first {
                return "\(first.currency) \(Self.fmt(first.totalBalance))"
            }
            if isFetching { return "余额…" }
            if lastError != nil { return "余额!" }
            return "—"
        }
        return timeFormatter.string(from: Date())
    }

    /// 气泡内容：台词段(3s) > 余额展示段(5s) > 当前模式（时间大字体）
    private var displayContent: (top: String, bottom: String, topSize: CGFloat, isPhrase: Bool) {
        let now = Date()
        if let p = phrase, let until = phraseUntil, now < until {
            return (p, "", 13, true)
        }
        if let until = peekUntil, now < until {
            phrase = nil
            let lines = balanceLines
            return (lines.0, lines.1, 13, false)
        }
        if let until = peekUntil, now >= until {
            phrase = nil
            peekUntil = nil
        }
        if mode == "time" {
            return (timeFormatter.string(from: Date()), "", 15, false)
        }
        let lines = balanceLines
        return (lines.0, lines.1, 13, false)
    }

    private var balanceLines: (String, String) {
        let symbol = balance.map { Self.symbol(for: $0.balanceInfos.first?.currency ?? "") } ?? ""
        let totalText = balance.flatMap { $0.balanceInfos.first.map { Self.fmt($0.totalBalance) } }
        let balanceLine = totalText.map { "DeepSeek 余额 \(symbol)\($0)" } ?? "DeepSeek 余额 —"
        let used = String(format: "%.2f", usageAmount)
        return (balanceLine, "今日已用 \(symbol)\(used)")
    }

    private var tooltipText: String {
        if mode == "time" {
            return "DeepSeek 余额 · 点击切换为余额"
        }
        if let b = balance, let first = b.balanceInfos.first {
            var tip = "\(first.currency) \(Self.fmt(first.totalBalance))"
            if let lu = lastUpdate {
                tip += " · 更新于 \(timeDetailFormatter.string(from: lu))"
            }
            return tip + " · 点击切换为时间"
        }
        return "余额获取中… · 点击切换为时间"
    }

    private func refreshDisplay() {
        guard let button = statusItem.button else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
        ]
        button.attributedTitle = NSAttributedString(string: displayText, attributes: attrs)
        button.toolTip = tooltipText
        let content = displayContent
        whale?.updateLines(content.top, content.bottom, topSize: content.topSize, isPhrase: content.isPhrase)
    }

    // MARK: Click / Menu

    @objc private func handleClick() {
        let eventType = NSApp.currentEvent?.type
        if eventType == .rightMouseUp {
            showMenu()
        } else {
            toggleMode()
        }
    }

    private func toggleMode() {
        mode = (mode == "time") ? "balance" : "time"
        Config.save(mode: mode)
        if mode == "balance" {
            let stale = lastUpdate.map { Date().timeIntervalSince($0) > 30 } ?? true
            if stale { fetchBalance() }
        }
        refreshDisplay()
    }

    private func showMenu() {
        let menu = buildMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.menu = nil
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let title = NSMenuItem(title: "DeepSeek 余额", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        menu.addItem(.separator())

        if let b = balance, !b.balanceInfos.isEmpty {
            for info in b.balanceInfos {
                let item = NSMenuItem(
                    title: "\(info.currency) 总余额 \(Self.fmt(info.totalBalance))",
                    action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
                let detail = NSMenuItem(
                    title: "  充值 \(Self.fmt(info.toppedUpBalance)) · 赠送 \(Self.fmt(info.grantedBalance))",
                    action: nil, keyEquivalent: "")
                detail.isEnabled = false
                menu.addItem(detail)
            }
        } else if isFetching {
            let item = NSMenuItem(title: "加载中…", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            let item = NSMenuItem(title: lastError ?? "暂无数据（右键菜单可立即刷新）", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        if let lu = lastUpdate {
            let item = NSMenuItem(
                title: "更新于 \(timeDetailFormatter.string(from: lu))", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let modeTime = NSMenuItem(title: "显示时间", action: #selector(switchToTime), keyEquivalent: "")
        modeTime.target = self
        modeTime.state = mode == "time" ? .on : .off
        menu.addItem(modeTime)

        let modeBalance = NSMenuItem(title: "显示余额", action: #selector(switchToBalance), keyEquivalent: "")
        modeBalance.target = self
        modeBalance.state = mode == "balance" ? .on : .off
        menu.addItem(modeBalance)

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "立即刷新", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let setKey = NSMenuItem(title: "设置 API Key…", action: #selector(setAPIKey), keyEquivalent: "")
        setKey.target = self
        menu.addItem(setKey)

        let setBase = NSMenuItem(title: "API 地址…", action: #selector(setAPIBase), keyEquivalent: "")
        setBase.target = self
        menu.addItem(setBase)

        let hideWhale = NSMenuItem(title: "显示小鲸鱼", action: #selector(toggleWhale), keyEquivalent: "")
        hideWhale.target = self
        hideWhale.state = (whale?.window.isVisible ?? false) ? .on : .off
        menu.addItem(hideWhale)

        if #available(macOS 13.0, *) {
            let auto = NSMenuItem(title: "开机自动启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
            auto.target = self
            auto.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
            menu.addItem(auto)
        }

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }

    // MARK: Actions

    @objc private func switchToTime() { if mode != "time" { toggleMode() } }
    @objc private func switchToBalance() { if mode != "balance" { toggleMode() } }
    @objc private func refreshNow() { fetchBalance() }

    /// 点击角色/气泡：Q 弹 + 随机台词（3s）→ 余额（5s）→ 恢复
    @objc private func bubbleClicked() {
        phrase = catchphrases.randomElement()
        phraseUntil = Date().addingTimeInterval(3)
        peekUntil = Date().addingTimeInterval(8)
        refreshDisplay()
    }

    @objc private func setAPIKey() { promptForAPIKey() }

    @objc private func setAPIBase() {
        let alert = NSAlert()
        alert.messageText = "DeepSeek API 地址"
        alert.informativeText = "默认 https://api.deepseek.com。使用第三方中转/代理服务时填写对应地址（例如 https://xxx.com），留空恢复默认。"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        field.stringValue = apiBase ?? "https://api.deepseek.com"
        alert.accessoryView = field
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let v = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            apiBase = v.isEmpty ? nil : v
            Config.save(apiBase: apiBase)
            fetchBalance()
        }
    }

    @objc private func toggleWhale() {
        guard let whale else { return }
        if whale.window.isVisible {
            whale.window.orderOut(nil)
        } else {
            whale.window.orderFrontRegardless()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            let svc = SMAppService.mainApp
            if svc.status == .enabled {
                try? svc.unregister()
            } else {
                try? svc.register()
            }
        }
    }

    private func promptForAPIKey() {
        let alert = NSAlert()
        alert.messageText = "DeepSeek API Key"
        alert.informativeText = "输入 DeepSeek 的 API Key（sk- 开头），用于获取账户余额。\n输入框已聚焦，可以直接 Cmd+V 粘贴。\n也可以写入 ~/.deepseek-balance/config.json 或设置环境变量 DEEPSEEK_API_KEY。"
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        field.placeholderString = "sk-..."
        if let cb = NSPasteboard.general.string(forType: .string), cb.hasPrefix("sk-") {
            field.stringValue = cb.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        alert.accessoryView = field
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        field.becomeFirstResponder()
        if alert.runModal() == .alertFirstButtonReturn {
            let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                apiKey = key
                Config.save(apiKey: key)
                fetchBalance()
            }
        }
    }

    // MARK: Fetch

    private func fetchBalance() {
        guard let key = apiKey else { return }
        guard !isFetching else { return }
        isFetching = true

        var request = URLRequest(url: URL(string: (apiBase ?? "https://api.deepseek.com") + "/user/balance")!)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isFetching = false

                if let error {
                    self.lastError = error.localizedDescription
                    self.refreshDisplay()
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    self.lastError = "无响应"
                    self.refreshDisplay()
                    return
                }
                guard http.statusCode == 200 else {
                    var msg = "HTTP \(http.statusCode)"
                    if let data,
                       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let err = obj["error"] as? [String: Any],
                       let m = err["message"] as? String {
                        msg = m
                    }
                    if msg.count > 70 { msg = String(msg.prefix(70)) + "…" }
                    self.lastError = msg
                    self.refreshDisplay()
                    return
                }
                guard let data else {
                    self.lastError = "空响应"
                    self.refreshDisplay()
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode(BalanceResponse.self, from: data)
                    self.balance = decoded
                    self.lastError = nil
                    self.lastUpdate = Date()
                    self.updateUsage(decoded)
                } catch {
                    self.lastError = "响应解析失败"
                }
                self.refreshDisplay()
            }
        }.resume()
    }

    // MARK: 今日已用记账（余额差值，跨天归零）

    private func updateUsage(_ b: BalanceResponse) {
        guard let first = b.balanceInfos.first,
              let total = Double(first.totalBalance) else { return }
        let today = Self.dayString()
        if usageDate != today {
            usageDate = today
            usageAmount = 0
            lastObserved = nil
        }
        if first.currency != usageCurrency {
            usageCurrency = first.currency
            lastObserved = nil
        }
        if let last = lastObserved, total < last {
            usageAmount += (last - total)
        }
        lastObserved = total
        Config.save(usage: [
            "date": usageDate,
            "amount": usageAmount,
            "lastObserved": lastObserved ?? -1,
            "currency": usageCurrency,
        ])
    }

    // MARK: Helpers

    static func fmt(_ s: String) -> String {
        guard let v = Double(s) else { return s }
        return String(format: "%.2f", v)
    }

    static func symbol(for currency: String) -> String {
        switch currency {
        case "CNY": return "¥"
        case "USD": return "$"
        default: return currency + " "
        }
    }

    static func dayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// MARK: - Entry

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
