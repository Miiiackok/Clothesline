import AppKit

let arguments = Set(CommandLine.arguments.dropFirst())
if arguments.contains("--version") {
    print("Clothesline 0.1.0")
    exit(EXIT_SUCCESS)
}
if arguments.contains("--help") || arguments.contains("-h") {
    print("""
    Clothesline · 桌面晾衣绳
    A tiny macOS shelf for screenshots, photos, and files.

    Usage: ./Clothesline [--help | --version]

    Launches in the menu bar (paperclip icon). Quit from that menu or press Ctrl-C.
    Screenshots and dropped images are moved into the app's storage; other files stay in place.
    Data: ~/Library/Application Support/Clothesline/
    Requires macOS 13 or later. Launch at login requires an app bundle.
    """)
    exit(EXIT_SUCCESS)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // 只在菜单栏，没有 Dock 图标
app.run()
