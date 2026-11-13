import AppKit
import WispCore

/// The question an assistant asks through Wisp: may I quit this app? One at a time,
/// and the default button is the safe one.
@MainActor
final class QuitPrompt {
    static let shared = QuitPrompt()
    private var open = false

    /// Returns false when a question is already on screen.
    func ask(name: String, bundleID: String, memory: UInt64, cpu: Double, reason: String) -> Bool {
        guard !open else { return false }
        open = true
        DispatchQueue.main.async { [self] in
            let alert = NSAlert()
            alert.messageText = L("An assistant asks to quit \(name)")
            var detail = L("\(name) is using \(Format.memory(memory)) of memory and \(Format.percent(cpu)) CPU.")
            if !reason.isEmpty { detail += "\n\n“\(reason)”" }
            alert.informativeText = detail + L("\n\nIt quits normally, so it can ask to save your work.")
            alert.addButton(withTitle: L("Keep Running"))
            alert.addButton(withTitle: L("Quit \(name)"))
            alert.icon = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleID }?.icon
            NSApp.activate()
            let answer = alert.runModal()
            open = false
            guard answer == .alertSecondButtonReturn else { return }
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) { app.terminate() }
        }
        return true
    }
}
