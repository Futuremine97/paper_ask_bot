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
        // Dock 아이콘 + 메뉴바 아이콘 모두 표시 (메뉴바가 가려져도 앱을 찾을 수 있도록)
        NSApp.setActivationPolicy(.regular)

        // 실행 직후 메인 창을 자동으로 열어, "아무것도 안 뜬다"는 상황을 방지
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if let state = AppRef.shared {
                MainWindowController.shared.show(state: state)
            }
        }
    }

    // Dock 아이콘을 다시 클릭하면 메인 창을 보여줌
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let state = AppRef.shared {
            MainWindowController.shared.show(state: state)
        }
        return true
    }
}
