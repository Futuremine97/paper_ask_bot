import SwiftUI
import AppKit

@main
struct PaperAssistApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra("Paper Assist", systemImage: "doc.text.magnifyingglass") {
            Button("영역 캡처 & 분석  (⌃⇧A)") {
                MainWindowController.shared.show(state: state)
                state.captureAndAnalyze(mode: .interactive)
            }
            Button("전체 화면 캡처 & 분석") {
                MainWindowController.shared.show(state: state)
                state.captureAndAnalyze(mode: .fullScreen)
            }
            Divider()
            Button("창 열기") {
                MainWindowController.shared.show(state: state)
            }
            Button("설정…") {
                state.showSettings = true
                MainWindowController.shared.show(state: state)
            }
            Divider()
            Button("종료") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock 아이콘 없이 메뉴바 전용 앱으로 실행
        NSApp.setActivationPolicy(.accessory)
    }
}
