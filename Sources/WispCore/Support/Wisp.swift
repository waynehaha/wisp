import Foundation

public enum Wisp {
    public static let version = "0.2.0"
    public static let bundleIdentifier = "app.wisp.Wisp"

    /// ~/Library/Application Support/Wisp, created on first use.
    public static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = Bundle.main.bundleIdentifier == "app.wisp.Wisp.zh-hans-preview" ? "Wisp中文预览" : "Wisp"
        let url = base.appendingPathComponent(folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
