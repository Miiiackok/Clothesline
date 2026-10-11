import AppKit

/// 菜单栏回形针。
final class MenuBarController: NSObject, NSMenuDelegate {
    struct Toggle {
        let title: String
        let get: () -> Bool
        let set: (Bool) -> Void
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let toggles: [Toggle]

    init(toggles: [Toggle]) {
        self.toggles = toggles
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Clothesline")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for toggle in toggles {
            let item = ClosureMenuItem(toggle.title) { toggle.set(!toggle.get()) }
            item.state = toggle.get() ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("退出 Clothesline") { NSApp.terminate(nil) })
    }
}
