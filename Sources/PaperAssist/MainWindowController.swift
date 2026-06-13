import AppKit
import SwiftUI

/// 분석 패널을 담는 독립 창. 메뉴바 버튼이나 단축키로 표시합니다.
@MainActor
final class MainWindowController {
    static let shared = MainWindowController()
    private init() {}

    private var window: NSWindow?

    func show(state: AppState) {
        if window == nil {
            let hosting = NSHostingView(rootView: ContentView().environmentObject(state))
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Paper Assist"
            win.contentView = hosting
            win.isReleasedWhenClosed = false
            win.center()
            win.setFrameAutosaveName("PaperAssistMain")
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
