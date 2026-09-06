import AppKit
import SwiftUI
import WatermarkCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let viewModel = EditorViewModel()
    private var windowController: NSWindowController?
    private var aboutWindowController: NSWindowController?
    private var statusItem: NSStatusItem?
    private var globalHotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        configureStatusItem()
        globalHotKey = GlobalHotKey { [weak self] in self?.quickApply() }
        showEditor()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showEditor()
        return true
    }

    @objc func showEditor() {
        if windowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1080, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "WatermarkFlow"
            window.minSize = NSSize(width: 900, height: 620)
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.titlebarAppearsTransparent = true
            window.contentView = NSHostingView(rootView: EditorView(viewModel: viewModel))
            windowController = NSWindowController(window: window)
        }
        NSApp.activate(ignoringOtherApps: true)
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func pasteAndEdit() {
        showEditor()
        viewModel.loadFromClipboard()
    }

    @objc func openImage() {
        showEditor()
        viewModel.openImage()
    }

    @objc func exportImage() {
        showEditor()
        viewModel.exportImage()
    }

    @objc func generateAndCopy() {
        showEditor()
        viewModel.generateAndCopy()
    }

    @objc func quickApply() {
        do {
            _ = try viewModel.quickApplyDefaultToClipboard()
            flashStatus(symbol: "checkmark.seal.fill")
            NSSound(named: "Tink")?.play()
        } catch {
            showEditor()
            viewModel.statusMessage = error.localizedDescription
            flashStatus(symbol: "exclamationmark.triangle.fill")
            NSSound.beep()
        }
    }

    @objc func showAbout() {
        if aboutWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 330),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "关于 WatermarkFlow"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = NSHostingView(rootView: AboutView())
            aboutWindowController = NSWindowController(window: window)
        }
        NSApp.activate(ignoringOtherApps: true)
        aboutWindowController?.showWindow(nil)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "seal.fill", accessibilityDescription: "WatermarkFlow")
        item.button?.toolTip = "WatermarkFlow · ⌥⌘W 快速加水印"

        let menu = NSMenu()
        menu.addItem(menuItem("打开编辑器", action: #selector(showEditor)))
        menu.addItem(menuItem("从剪贴板载入并编辑", action: #selector(pasteAndEdit)))
        let quick = menuItem("默认模板快速生成并复制", action: #selector(quickApply), key: "w")
        quick.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(quick)
        menu.addItem(.separator())
        menu.addItem(menuItem("关于 WatermarkFlow", action: #selector(showAbout)))
        menu.addItem(menuItem("退出", action: #selector(quit), key: "q"))
        item.menu = menu
        statusItem = item
    }

    private func configureMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(menuItem("关于 WatermarkFlow", action: #selector(showAbout)))
        appMenu.addItem(.separator())
        appMenu.addItem(menuItem("退出 WatermarkFlow", action: #selector(quit), key: "q"))
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        fileItem.title = "文件"
        let fileMenu = NSMenu(title: "文件")
        fileMenu.addItem(menuItem("打开图片…", action: #selector(openImage), key: "o"))
        fileMenu.addItem(menuItem("从剪贴板载入", action: #selector(pasteAndEdit)))
        fileMenu.addItem(menuItem("导出文件…", action: #selector(exportImage), key: "e"))
        fileMenu.addItem(menuItem("生成并复制", action: #selector(generateAndCopy), key: "\r"))
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        let editItem = NSMenuItem()
        editItem.title = "编辑"
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func menuItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func flashStatus(symbol: String) {
        guard let button = statusItem?.button else { return }
        let original = button.image
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            button.image = original
        }
    }
}
