import AppKit
import CoreAudio
import WispCore

/// A card with a title and a list of rows, sized to its rows.
final class ListCard: CardView {
    let title = TextLine()
    let empty = TextLine()
    private(set) var rows: [ListRow] = []

    func set(count: Int, configure: (ListRow, Int) -> Void) {
        while rows.count < count {
            let row = ListRow()
            addSubview(row)
            rows.append(row)
        }
        for (index, row) in rows.enumerated() {
            row.isHidden = index >= count
            if index < count {
                row.showsRule = index < count - 1
                configure(row, index)
            }
        }
        empty.isHidden = count > 0
        needsLayout = true
    }

    var wantedHeight: CGFloat { 60 + CGFloat(max(1, rows.filter { !$0.isHidden }.count)) * 34 }

    override init() {
        super.init()
        addSubview(title)
        addSubview(empty)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let width = bounds.width - 40
        title.frame = NSRect(x: 20, y: 16, width: width, height: 20)
        empty.frame = NSRect(x: 20, y: 54, width: width, height: 14)
        for (index, row) in rows.enumerated() { row.frame = NSRect(x: 20, y: 46 + CGFloat(index) * 34, width: width, height: 34) }
    }
}

// MARK: - Sensors

@MainActor
final class SensorsCardPage: CardPage {
    override var pageTint: NSColor { PageID.sensors.tint }
    private let (titleLine, caption): (TextLine, TextLine)
    private let temperatures = ListCard()
    private let fans = ListCard()
    private let accessories = ListCard()
    private var accessoriesAt = Date.distantPast
    override var toolbarHeading: (NSView, NSView)? { (titleLine, caption) }

    override init(delegate: AppDelegate) {
        let title = TextLine(Toolbar.title(L("Sensors")))
        (titleLine, caption) = (title, TextLine())
        super.init(delegate: delegate)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()
        for view in [temperatures, fans, accessories] as [NSView] { canvas.addSubview(view) }
        temperatures.title.text = cardTitle(L("Temperatures"), "")
        fans.title.text = cardTitle(L("Fans"), "")
        accessories.title.text = cardTitle(L("Accessories"), "")
        temperatures.empty.text = Theme.caption(L("No temperature sensors found"))
        fans.empty.text = Theme.caption(L("This Mac has no fans"))
        accessories.empty.text = Theme.caption(L("No Bluetooth keyboard, mouse or trackpad reports a battery"))
    }

    override func arrange(width: CGFloat) -> CGFloat {
        let inner = width - margin * 2
        titleLine.frame = NSRect(x: margin + 2, y: margin, width: 200, height: 26)
        caption.frame = NSRect(x: margin + 2, y: margin + 30, width: inner, height: 14)
        var y = margin
        let half = (inner - gap) / 2
        temperatures.frame = NSRect(x: margin, y: y, width: width > 900 ? half : inner, height: temperatures.wantedHeight)
        if width > 900 {
            fans.frame = NSRect(x: margin + half + gap, y: y, width: half, height: fans.wantedHeight)
            accessories.frame = NSRect(x: margin + half + gap, y: fans.frame.maxY + gap, width: half, height: accessories.wantedHeight)
            y = max(temperatures.frame.maxY, accessories.frame.maxY)
        } else {
            fans.frame = NSRect(x: margin, y: temperatures.frame.maxY + gap, width: inner, height: fans.wantedHeight)
            accessories.frame = NSRect(x: margin, y: fans.frame.maxY + gap, width: inner, height: accessories.wantedHeight)
            y = accessories.frame.maxY
        }
        return y + margin
    }

    override func update(system s: SystemSnapshot) {
        guard let t = s.thermal else { return }
        caption.text = Theme.caption(L("Thermal pressure \(L10n.string(t.pressure.rawValue))"), color: t.pressure == .nominal ? Theme.inkTertiary : Theme.warn)
        let sensors = t.sensors
        let before = temperatures.wantedHeight
        temperatures.set(count: sensors.count) { row, index in
            let sensor = sensors[index]
            row.name = sensor.name
            row.value = Format.celsius(sensor.celsius)
            row.fraction = sensor.celsius / 110
            row.barColor = sensor.celsius >= 95 ? Theme.bad : (sensor.celsius >= 80 ? Theme.warn : Theme.accent)
        }
        fans.set(count: t.fans.count) { row, index in
            let fan = t.fans[index]
            row.name = L("Fan \(fan.index + 1)")
            row.note = [fan.minRPM, fan.maxRPM].compactMap { $0 }.count == 2 ? L("\(Int(fan.minRPM!))–\(Int(fan.maxRPM!)) rpm") : ""
            row.value = L("\(Int(fan.rpm)) rpm")
            row.fraction = fan.maxRPM.map { fan.rpm / max($0, 1) } ?? 0
        }
        if Date().timeIntervalSince(accessoriesAt) > 30 {
            accessoriesAt = Date()
            let batteries = Accessories.batteries()
            accessories.set(count: batteries.count) { row, index in
                row.name = batteries[index].name
                row.value = "\(batteries[index].percent)%"
                row.fraction = Double(batteries[index].percent) / 100
                row.barColor = batteries[index].percent <= 15 ? Theme.bad : Theme.good
            }
        }
        if before != temperatures.wantedHeight || fans.frame.height != fans.wantedHeight { relayout() }
    }
}

// MARK: - Neural Engine

@MainActor
final class NeuralPage: MachinePage {
    private let now = Tile(L("Power now")), average = Tile(L("Average")), peak = Tile(L("Peak"))
    private var ring = RecentRing(capacity: HistoryStore.recentSamples)

    override func setUp() {
        hero.range.items = [L("Live")]
        hero.chart.format = { String(format: $0 >= 1 || $0 == 0 ? "%.0f W" : "%.1f W", $0) }
        hero.chart.minimumCeiling = 1
        hero.figure.format = { (String(format: $0 >= 1 ? "%.1f" : "%.2f", $0), "W") }
        tiles = [now, average, peak]
        table.isHidden = true
        tableCard.isHidden = true
    }

    override func arrange(width: CGFloat) -> CGFloat {
        _ = super.arrange(width: width)
        return (tiles.last?.frame.maxY ?? hero.frame.maxY) + margin
    }

    override func refreshChart(force: Bool) {
        hero.chart.step = delegate.settings.interval
        hero.chart.primary = ring.values
    }

    override func update(system s: SystemSnapshot) {
        guard let p = s.power else {
            hero.figure.show("–")
            hero.meta.text = Theme.caption(L("Chip power is not readable on this Mac"))
            return
        }
        let watts = p.ane ?? 0
        ring.append(Float(watts))
        refreshChart(force: false)
        hero.figure.set(watts)
        hero.meta.text = Theme.caption(watts > 0.01 ? L("In use · macOS does not say which app is using it") : L("Idle · nothing is running models on it now"))
        hero.needsLayout = true
        let values = ring.values
        now.set(text: String(format: "%.2f", watts), unit: "W")
        now.set(note: L("Right now"))
        average.set(text: String(format: "%.2f", Double(values.reduce(0, +)) / Double(max(values.count, 1))), unit: "W")
        average.set(note: L("In the chart above"))
        peak.set(text: String(format: "%.2f", Double(values.max() ?? 0)), unit: "W")
        peak.set(note: L("In the chart above"))
    }

    override func update(table: ProcessTable) {}
}

// MARK: - Sound

/// One default device: which one, its volume as a figure, and a slider.
final class DeviceCard: CardView {
    let title = TextLine()
    let picker = MenuButton()
    let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    let level = BigNumber()

    override init() {
        super.init()
        slider.controlSize = .regular
        level.font = Theme.figure(30)
        level.unitFont = Theme.sans(15, .medium)
        for view in [title, picker, slider, level] as [NSView] { addSubview(view) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(volume: Float?) {
        if let volume { level.show(String(format: "%.0f", volume * 100), unit: "%") } else { level.show(L("Fixed")) }
    }

    override func layout() {
        super.layout()
        let width = bounds.width - 32
        title.frame = NSRect(x: 16, y: 13, width: 90, height: 20)
        let pickerWidth = min(picker.naturalWidth, width - 100)
        picker.frame = NSRect(x: bounds.width - 16 - pickerWidth, y: 10, width: pickerWidth, height: 26)
        level.frame = NSRect(x: 16, y: 40, width: width, height: 38)
        slider.frame = NSRect(x: 14, y: 86, width: width + 4, height: 22)
    }
}

@MainActor
final class SoundPage: CardPage {
    override var pageTint: NSColor { PageID.sound.tint }
    private let output = DeviceCard()
    private let input = DeviceCard()
    private let apps = ListCard()
    private lazy var titleLines = heading(L("Sound"))
    private var caption: TextLine { titleLines.1 }
    private var checkedAt = Date.distantPast
    private var devices: [AudioDevice] = []

    override func loadView() {
        super.loadView()
        for view in [output, input, apps] as [NSView] { canvas.addSubview(view) }
        output.title.text = cardTitle(L("Output"), "")
        input.title.text = cardTitle(L("Input"), "")
        apps.title.text = cardTitle(L("Apps with sound open"), "")
        apps.empty.text = Theme.caption(L("No app has sound open"))
        for (card, isInput) in [(output, false), (input, true)] {
            card.slider.target = self
            card.slider.action = isInput ? #selector(inputVolume(_:)) : #selector(outputVolume(_:))
            card.picker.onPick = { [weak self] index in self?.pick(index, input: isInput) }
        }
        refresh()
    }

    override func arrange(width: CGFloat) -> CGFloat {
        let inner = width - margin * 2
        let half = (inner - gap) / 2
        let top = place(titleLines.0, titleLines.1, width: width)
        output.frame = NSRect(x: margin, y: top, width: half, height: 122)
        input.frame = NSRect(x: margin + half + gap, y: top, width: half, height: 122)
        apps.frame = NSRect(x: margin, y: output.frame.maxY + gap, width: inner, height: apps.wantedHeight)
        return apps.frame.maxY + margin
    }

    override func update(system: SystemSnapshot) {
        if Date().timeIntervalSince(checkedAt) >= 2 { refresh() }
    }

    private func refresh() {
        checkedAt = Date()
        devices = Audio.devices()
        for (card, isInput) in [(output, false), (input, true)] {
            let candidates = devices.filter { isInput ? $0.hasInput : $0.hasOutput }
            let current = Audio.defaultDevice(input: isInput)
            let titles = candidates.map(\.name)
            card.picker.titles = titles
            if let index = candidates.firstIndex(where: { $0.id == current }) { card.picker.selected = index }
            card.needsLayout = true
            let volume = current.flatMap { Audio.volume($0, input: isInput) }
            card.slider.isEnabled = volume != nil
            if let volume, card.slider.window?.currentEvent?.type != .leftMouseDragged { card.slider.floatValue = volume }
            card.show(volume: volume)
        }
        let clients = Audio.clients()
        let table = delegate.table
        var groupOf: [Int32: AppGroup] = [:]
        for app in table.apps { for pid in app.pids { groupOf[pid] = app } }
        var byApp: [String: (name: String, icon: NSImage?, playing: Bool, recording: Bool)] = [:]
        for client in clients {
            // Helpers and audio services count toward the app they belong to; background
            // daemons are left out unless they are making sound.
            let group = groupOf[client.pid]
            guard group?.kind == .app || client.playing || client.recording else { continue }
            let name = group?.name ?? NSRunningApplication(processIdentifier: client.pid)?.localizedName ?? L("Process \(client.pid)")
            let icon = group.map { Icons.icon(for: $0) } ?? NSRunningApplication(processIdentifier: client.pid)?.icon
            var entry = byApp[name] ?? (name, icon, false, false)
            entry.playing = entry.playing || client.playing
            entry.recording = entry.recording || client.recording
            byApp[name] = entry
        }
        let sorted = byApp.values.sorted { ($0.playing || $0.recording ? 0 : 1, $0.name) < ($1.playing || $1.recording ? 0 : 1, $1.name) }
        let playing = sorted.filter(\.playing).count
        caption.text = Theme.caption(L("\(sorted.count) apps with sound open · \(playing == 0 ? L("none") : "\(playing)") playing"))
        apps.set(count: sorted.count) { row, index in
            let entry = sorted[index]
            row.icon = entry.icon ?? NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: nil)
            row.name = entry.name
            row.note = entry.recording ? L("Using the microphone") : ""
            row.value = entry.playing ? L("Playing") : (entry.recording ? L("Recording") : L("Silent"))
            row.showsBar = false
        }
        relayout()
    }

    private func pick(_ index: Int, input: Bool) {
        let candidates = devices.filter { input ? $0.hasInput : $0.hasOutput }
        if candidates.indices.contains(index) { Audio.setDefaultDevice(candidates[index].id, input: input) }
        refresh()
    }

    @objc private func outputVolume(_ sender: NSSlider) {
        if let id = Audio.defaultDevice(input: false) { Audio.setVolume(id, input: false, to: sender.floatValue) }
        output.show(volume: sender.floatValue)
    }

    @objc private func inputVolume(_ sender: NSSlider) {
        if let id = Audio.defaultDevice(input: true) { Audio.setVolume(id, input: true, to: sender.floatValue) }
        input.show(volume: sender.floatValue)
    }
}

// MARK: - Bluetooth

@MainActor
final class BluetoothPage: CardPage {
    override var pageTint: NSColor { PageID.bluetooth.tint }
    private let header = CardView()
    private let headline = TextLine()
    private let detail = TextLine()
    private lazy var settingsButton = ActionButton(title: L("Bluetooth Settings…"), target: self, action: #selector(openSettings))
    private var asking = false
    private let list = ListCard()
    private var checkedAt = Date.distantPast
    private lazy var titleLines = heading(L("Bluetooth"))

    override func loadView() {
        super.loadView()
        titleLines.1.text = Theme.caption(L("Paired devices and their batteries"))
        canvas.addSubview(header)
        canvas.addSubview(list)
        for view in [headline, detail, settingsButton] as [NSView] { header.addSubview(view) }
        list.title.text = cardTitle(L("Devices"), "")
        list.empty.text = Theme.caption(Bluetooth.allowed ? L("No paired devices") : L("Wisp needs Bluetooth access to list devices"))
    }

    override func arrange(width: CGFloat) -> CGFloat {
        let inner = width - margin * 2
        header.frame = NSRect(x: margin, y: place(titleLines.0, titleLines.1, width: width), width: inner, height: 76)
        headline.frame = NSRect(x: 20, y: 16, width: inner - 220, height: 22)
        detail.frame = NSRect(x: 20, y: 42, width: inner - 220, height: 14)
        let size = settingsButton.intrinsicContentSize
        settingsButton.frame = NSRect(x: inner - 20 - size.width, y: (76 - size.height) / 2, width: size.width, height: size.height)
        list.frame = NSRect(x: margin, y: header.frame.maxY + gap, width: inner, height: list.wantedHeight)
        return list.frame.maxY + margin
    }

    override func update(system: SystemSnapshot) {
        guard Date().timeIntervalSince(checkedAt) > 10 || asking else { return }
        checkedAt = Date()
        if Bluetooth.undecided, !asking {
            headline.text = NSAttributedString(string: L("Bluetooth access"), attributes: [.font: Theme.sans(16, .medium), .foregroundColor: Theme.ink])
            detail.text = Theme.caption(L("Wisp asks macOS once, then lists your devices and their batteries"))
            settingsButton.title = L("Allow…")
            settingsButton.action = #selector(allow)
            relayout()
            return
        }
        settingsButton.title = L("Bluetooth Settings…")
        settingsButton.action = #selector(openSettings)
        let devices = Bluetooth.devices(asking: asking)
        asking = false
        let connected = devices.filter(\.connected)
        headline.text = NSAttributedString(string: L("\(connected.count) connected"),
                                           attributes: [.font: Theme.sans(16, .medium), .foregroundColor: Theme.ink])
        let batteries = connected.filter { $0.battery != nil }.count
        detail.text = Theme.caption(L("\(batteries == 0 ? L("No battery reported") : L("\(batteries) report a battery")) · \(devices.count - connected.count) paired, away"))
        list.set(count: devices.count) { row, index in
            let device = devices[index]
            let symbol = ["Headphones": "headphones", "Phone": "iphone", "Keyboard": "keyboard", "Mouse": "computermouse",
                          "Computer": "laptopcomputer"][device.kind] ?? "dot.radiowaves.left.and.right"
            row.icon = NSImage(systemSymbolName: symbol, accessibilityDescription: device.kind)
            row.name = device.name
            row.note = L10n.string(device.kind)
            row.value = device.battery.map { "\($0)%" } ?? (device.connected ? L("Not reported") : L("Away"))
            row.fraction = Double(device.battery ?? 0) / 100
            row.showsBar = device.battery != nil
            row.barColor = (device.battery ?? 100) <= 15 ? Theme.bad : Theme.good
        }
        relayout()
    }

    @objc private func allow() {
        asking = true
        update(system: delegate.system)
    }

    @objc private func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings")!)
    }
}
