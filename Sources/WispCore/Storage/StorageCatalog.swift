import Foundation

/// The slices of the whole-disk bar.
public enum StorageCategory: String, Codable, CaseIterable, Sendable {
    case apps, developer, documents, mail, system, snapshots, purgeable, free

    public var title: String {
        switch self {
        case .apps: return L("Apps")
        case .developer: return L("Developer")
        case .documents: return L("Documents & Media")
        case .mail: return L("Mail & Messages")
        case .system: return L("macOS & System Data")
        case .snapshots: return L("Snapshots")
        case .purgeable: return L("Purgeable")
        case .free: return L("Free")
        }
    }
}

/// A known place on disk: which slice it belongs to, the row it adds up into and
/// one line on what it is or what deleting it does.
struct StorageLocation {
    let row: String
    let category: StorageCategory
    /// Relative to the home folder, or absolute when it starts with "/".
    let paths: [String]
    let name: String
    let detail: String
}

enum StorageCatalog {
    static let developer: [StorageLocation] = [
        .init(row: "deriveddata", category: .developer, paths: ["Library/Developer/Xcode/DerivedData"], name: L("Xcode DerivedData"),
              detail: L("Build products and indexes. Xcode makes them again; the next build takes longer")),
        .init(row: "archives", category: .developer, paths: ["Library/Developer/Xcode/Archives"], name: L("Xcode archives"),
              detail: L("Builds you archived, with their debug symbols for reading crash reports")),
        .init(row: "devicesupport", category: .developer,
              paths: ["Library/Developer/Xcode/iOS DeviceSupport", "Library/Developer/Xcode/watchOS DeviceSupport",
                      "Library/Developer/Xcode/tvOS DeviceSupport", "Library/Developer/Xcode/visionOS DeviceSupport"],
              name: L("Device support"), detail: L("Symbols copied from devices you connected. Xcode copies them again next time")),
        .init(row: "simulators", category: .developer, paths: ["Library/Developer/CoreSimulator/Devices"], name: L("Simulators"),
              detail: L("Simulated devices with their apps and data. Deleting one removes everything in it")),
        .init(row: "simcaches", category: .developer, paths: ["Library/Developer/CoreSimulator/Caches"], name: L("Simulator caches"),
              detail: L("Made again the next time a simulator starts")),
        .init(row: "previews", category: .developer, paths: ["Library/Developer/Xcode/UserData/Previews"], name: L("SwiftUI previews"),
              detail: L("Preview builds. Made again when you open a preview")),
        .init(row: "xcodeother", category: .developer, paths: ["Library/Developer"], name: L("Other Xcode data"),
              detail: L("Settings, logs and products Xcode keeps")),
        .init(row: "docker", category: .developer, paths: ["Library/Containers/com.docker.docker/Data/vms"], name: "Docker Desktop",
              detail: L("The Linux disk with every image, container and volume. Prune from Docker instead of deleting it")),
        .init(row: "orbstack", category: .developer, paths: ["Library/Group Containers/HUC964yHBR.dev.orbstack", ".orbstack"], name: "OrbStack",
              detail: L("Disk of OrbStack's Linux machine with images and containers. Clean up from OrbStack")),
        .init(row: "colima", category: .developer, paths: [".colima"], name: "Colima",
              detail: L("Virtual machine disks. colima delete removes a machine and its images")),
        .init(row: "lima", category: .developer, paths: [".lima"], name: "Lima", detail: L("Virtual machine disks. limactl delete removes one")),
        .init(row: "podman", category: .developer, paths: [".local/share/containers"], name: "Podman",
              detail: L("Machine disks and images. podman machine rm removes a machine")),
        .init(row: "homebrew", category: .developer, paths: ["Library/Caches/Homebrew"], name: L("Homebrew downloads"),
              detail: L("Bottles and sources brew can download again")),
        .init(row: "npm", category: .developer, paths: [".npm"], name: L("npm cache"), detail: L("Packages npm downloads again when needed")),
        .init(row: "pnpm", category: .developer, paths: ["Library/pnpm", ".pnpm-store", ".local/share/pnpm"], name: L("pnpm store"),
              detail: L("Shared packages for your projects. pnpm downloads them again")),
        .init(row: "yarn", category: .developer, paths: ["Library/Caches/Yarn", ".yarn/berry/cache"], name: L("Yarn cache"),
              detail: L("Packages yarn downloads again when needed")),
        .init(row: "bun", category: .developer, paths: [".bun/install/cache"], name: L("Bun cache"), detail: L("Packages bun downloads again")),
        .init(row: "pip", category: .developer, paths: ["Library/Caches/pip"], name: L("pip cache"), detail: L("Wheels pip downloads again")),
        .init(row: "uv", category: .developer, paths: [".cache/uv", "Library/Caches/uv"], name: L("uv cache"),
              detail: L("Packages and Python builds uv fetches again")),
        .init(row: "poetry", category: .developer, paths: ["Library/Caches/pypoetry"], name: L("Poetry cache"), detail: L("Packages Poetry downloads again")),
        .init(row: "cargo", category: .developer, paths: [".cargo/registry", ".cargo/git"], name: L("Cargo registry"),
              detail: L("Crate sources cargo downloads again")),
        .init(row: "rustup", category: .developer, paths: [".rustup"], name: L("Rust toolchains"), detail: L("Toolchains rustup installed")),
        .init(row: "gomod", category: .developer, paths: ["go/pkg/mod"], name: L("Go modules"), detail: L("Module sources go downloads again")),
        .init(row: "gobuild", category: .developer, paths: ["Library/Caches/go-build"], name: L("Go build cache"), detail: L("Compiled packages go builds again")),
        .init(row: "gradle", category: .developer, paths: [".gradle"], name: "Gradle", detail: L("Dependencies and build caches Gradle fetches again")),
        .init(row: "maven", category: .developer, paths: [".m2/repository"], name: L("Maven repository"), detail: L("Dependencies Maven downloads again")),
        .init(row: "cocoapods", category: .developer, paths: ["Library/Caches/CocoaPods", ".cocoapods"], name: "CocoaPods",
              detail: L("Pod sources and specs CocoaPods downloads again")),
        .init(row: "swiftpm", category: .developer, paths: ["Library/Caches/org.swift.swiftpm", "Library/org.swift.swiftpm"], name: L("Swift packages"),
              detail: L("Package checkouts Swift downloads again")),
        .init(row: "playwright", category: .developer, paths: ["Library/Caches/ms-playwright", ".cache/puppeteer"], name: L("Test browsers"),
              detail: L("Browsers Playwright and Puppeteer download again")),
        .init(row: "jetbrains", category: .developer, paths: ["Library/Caches/JetBrains"], name: L("JetBrains caches"),
              detail: L("Indexes the IDE builds again")),
        .init(row: "ollama", category: .developer, paths: [".ollama/models"], name: L("Ollama models"),
              detail: L("Models you pulled. ollama pull downloads them again")),
        .init(row: "huggingface", category: .developer, paths: [".cache/huggingface"], name: "Hugging Face",
              detail: L("Models and datasets. They download again on next use")),
        .init(row: "lmstudio", category: .developer, paths: [".lmstudio/models", ".cache/lm-studio/models"], name: L("LM Studio models"),
              detail: L("Models you downloaded in LM Studio")),
        .init(row: "nodeversions", category: .developer, paths: [".nvm", ".volta", ".local/share/fnm"], name: L("Node versions"),
              detail: L("Node installs from nvm, Volta or fnm")),
        .init(row: "conda", category: .developer, paths: ["miniconda3", "anaconda3", "miniforge3", ".conda"], name: "Conda",
              detail: L("Python environments and packages")),
        .init(row: "pyenv", category: .developer, paths: [".pyenv"], name: "pyenv", detail: L("Python versions pyenv built")),
        .init(row: "homebrewcellar", category: .developer, paths: ["/opt/homebrew"], name: L("Homebrew packages"),
              detail: L("Everything brew installed. brew uninstall removes a package")),
        .init(row: "usrlocal", category: .developer, paths: ["/usr/local"], name: "Tools in /usr/local", detail: L("Command-line tools installed there")),
        .init(row: "librarydeveloper", category: .developer, paths: ["/Library/Developer"], name: L("Command Line Tools and runtimes"),
              detail: L("Xcode's command-line tools and simulator runtimes. Remove runtimes in Xcode settings")),
    ]

    /// Folders inside projects that the next build or install makes again.
    struct Artifact {
        let name: String
        let row: String
        let title: String
        let detail: String
        /// A file next to (parent) or inside (self) the folder that shows it is what it looks like.
        let markers: [String]
        let markerInside: Bool
    }

    static let artifacts: [Artifact] = [
        .init(name: "node_modules", row: "node_modules", title: "node_modules",
              detail: L("Packages for JavaScript projects. npm install brings them back"), markers: [], markerInside: false),
        .init(name: "target", row: "target", title: L("Rust target folders"), detail: L("Build output. cargo build makes it again"),
              markers: ["Cargo.toml"], markerInside: false),
        .init(name: ".venv", row: "venv", title: L("Python environments"), detail: L("Packages for one project. uv sync or pip install rebuilds it"),
              markers: ["pyvenv.cfg"], markerInside: true),
        .init(name: "venv", row: "venv", title: L("Python environments"), detail: L("Packages for one project. uv sync or pip install rebuilds it"),
              markers: ["pyvenv.cfg"], markerInside: true),
        .init(name: "build", row: "build", title: L("Build folders"), detail: L("Build output. The next build makes it again"),
              markers: ["build.gradle", "build.gradle.kts", "CMakeLists.txt", "package.json", "setup.py", "pyproject.toml", "meson.build", "Makefile"],
              markerInside: false),
        .init(name: ".build", row: "build", title: L("Build folders"), detail: L("Build output. The next build makes it again"),
              markers: ["Package.swift"], markerInside: false),
        .init(name: "Pods", row: "build", title: L("Build folders"), detail: L("Build output. The next build makes it again"),
              markers: ["Podfile"], markerInside: false),
    ]

    static let artifactNames = Set(artifacts.map(\.name))

    /// Everything that is not developer data, by home-relative path.
    static let places: [StorageLocation] = [
        .init(row: "apps", category: .apps, paths: ["Applications", "/Applications"], name: L("Apps"), detail: ""),
        .init(row: "mail", category: .mail, paths: ["Library/Mail", "Library/Containers/com.apple.mail", "Library/Group Containers/group.com.apple.mail"],
              name: "Mail", detail: L("Messages and attachments Mail downloaded")),
        .init(row: "messages", category: .mail, paths: ["Library/Messages", "Library/Containers/com.apple.MobileSMS"], name: "Messages",
              detail: L("Conversations and attachments")),
        .init(row: "desktop", category: .documents, paths: ["Desktop"], name: "Desktop", detail: ""),
        .init(row: "documents", category: .documents, paths: ["Documents"], name: L("Documents"), detail: ""),
        .init(row: "downloads", category: .documents, paths: ["Downloads"], name: L("Downloads"), detail: ""),
        .init(row: "pictures", category: .documents, paths: ["Pictures"], name: "Pictures", detail: ""),
        .init(row: "movies", category: .documents, paths: ["Movies"], name: "Movies", detail: ""),
        .init(row: "music", category: .documents, paths: ["Music"], name: "Music", detail: ""),
        .init(row: "icloud", category: .documents, paths: ["Library/Mobile Documents"], name: "iCloud Drive", detail: L("Files kept on this Mac")),
        .init(row: "cloud", category: .documents, paths: ["Library/CloudStorage"], name: L("Cloud storage"),
              detail: L("Dropbox, Google Drive, OneDrive and others, kept on this Mac")),
        .init(row: "backups", category: .system, paths: ["Library/Application Support/MobileSync/Backup"], name: L("iPhone and iPad backups"),
              detail: L("Finder backups of your devices")),
        .init(row: "caches", category: .system, paths: ["Library/Caches", "/Library/Caches"], name: L("Caches"),
              detail: L("Apps make these again as needed")),
        .init(row: "logs", category: .system, paths: ["Library/Logs", "/Library/Logs"], name: L("Logs"), detail: L("Records apps and macOS keep for problems")),
        .init(row: "appdata", category: .system,
              paths: ["Library/Application Support", "Library/Containers", "Library/Group Containers"], name: L("App data"),
              detail: L("Settings, databases and downloads apps keep")),
        .init(row: "trash", category: .system, paths: [".Trash"], name: L("Trash"), detail: L("Files you deleted. Empty the Trash in Finder")),
        .init(row: "library", category: .system, paths: ["Library"], name: L("Other Library folders"), detail: L("Fonts, keychains, mailboxes and settings")),
        .init(row: "systemlibrary", category: .system, paths: ["/Library"], name: L("Shared library"),
              detail: L("Fonts, drivers and app support for every user")),
    ]

    /// This user's folder under /private/var/folders: temporary files and caches macOS keeps per user.
    static let temporary = StorageLocation(row: "temporary", category: .system, paths: [], name: L("Temporary files"),
                                           detail: L("Per-user caches and temporary files. macOS clears them at restart or when space runs low"))

    /// Folders in the home folder that usually hold code.
    static let codeFolders = ["src", "Developer", "Projects", "projects", "code", "Code", "dev", "repos", "git", "GitHub", "workspace", "Sites"]

    /// Rule for a node: the most specific location whose path is exactly this one.
    static let rules: [String: StorageLocation] = {
        var table: [String: StorageLocation] = [:]
        for location in places + developer { for path in location.paths where table[path] == nil { table[path] = location } }
        return table
    }()

    static func location(row: String) -> StorageLocation? {
        (developer + places + [temporary]).first { $0.row == row }
    }
}
