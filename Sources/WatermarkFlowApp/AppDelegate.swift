import AppKit
import SwiftUI
import WatermarkCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private let viewModel = EditorViewModel()
    private var windowController: NSWindowController?
    private var aboutWindowController: NSWindowController?
    private var statusItem: NSStatusItem?
    private var globalHotKey: GlobalHotKey?
    private var quickTemplateMenu: NSMenu?
    private var defaultQuickMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        let requestedHotKey = viewModel.hotKeyConfiguration
        globalHotKey = GlobalHotKey(configuration: requestedHotKey) { [weak self] in
            self?.quickApply()
        }
        if globalHotKey?.isRegistered != true {
            if requestedHotKey != .default,
               globalHotKey?.update(configuration: .default) == true {
                viewModel.adoptStartupHotKeyFallback(.default)
            } else {
                viewModel.reportStartupHotKeyFailure()
            }
        }
        configureStatusItem()
        viewModel.hotKeyRegistrationHandler = { [weak self] configuration in
            self?.updateGlobalHotKey(configuration) ?? false
        }
        showEditor()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showEditor()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.flushPersistence()
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
            window.isRestorable = false
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

    @objc func clearCanvas() {
        showEditor()
        viewModel.clearCanvas()
    }

    @objc func quickApply() {
        performQuickApply(templateID: viewModel.defaultTemplateID)
    }

    @objc func quickApplyTemplate(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String,
              let templateID = UUID(uuidString: value) else { return }
        performQuickApply(templateID: templateID)
    }

    private func performQuickApply(templateID: UUID) {
        do {
            _ = try viewModel.quickApplyTemplateToClipboard(id: templateID)
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
            window.isRestorable = false
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
        item.button?.toolTip = "WatermarkFlow · \(viewModel.hotKeyConfiguration.displayName) 快速加水印"

        let menu = NSMenu()
        menu.addItem(menuItem("打开编辑器", action: #selector(showEditor)))
        menu.addItem(menuItem("从剪贴板载入并编辑", action: #selector(pasteAndEdit)))
        let quick = NSMenuItem(title: "选择模板快速生成并复制", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "选择模板快速生成并复制")
        submenu.delegate = self
        quick.submenu = submenu
        quickTemplateMenu = submenu
        rebuildQuickTemplateMenu()
        menu.addItem(quick)
        let defaultQuick = menuItem(
            "使用默认模板 · \(viewModel.hotKeyConfiguration.displayName)",
            action: #selector(quickApply)
        )
        defaultQuickMenuItem = defaultQuick
        menu.addItem(defaultQuick)
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
        fileMenu.addItem(.separator())
        let clear = menuItem("清空图片与水印画布", action: #selector(clearCanvas), key: "\u{8}")
        clear.keyEquivalentModifierMask = [.command]
        fileMenu.addItem(clear)
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

    func menuWillOpen(_ menu: NSMenu) {
        if menu === quickTemplateMenu {
            rebuildQuickTemplateMenu()
        }
    }

    private func rebuildQuickTemplateMenu() {
        guard let menu = quickTemplateMenu else { return }
        menu.removeAllItems()
        for template in viewModel.templates {
            let item = menuItem(template.name, action: #selector(quickApplyTemplate(_:)))
            item.representedObject = template.id.uuidString
            item.state = template.id == viewModel.defaultTemplateID ? .on : .off
            menu.addItem(item)
        }
    }

    private func updateGlobalHotKey(_ configuration: HotKeyConfiguration) -> Bool {
        guard globalHotKey?.update(configuration: configuration) == true else { return false }
        defaultQuickMenuItem?.title = "使用默认模板 · \(configuration.displayName)"
        statusItem?.button?.toolTip = "WatermarkFlow · \(configuration.displayName) 快速加水印"
        return true
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
