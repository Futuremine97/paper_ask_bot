import SwiftUI
import AppKit

@main
struct PaperAssistApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(state)
                .frame(width: 430, height: 600)
        } label: {
            Image(systemName: "viewfinder")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 메뉴바 전용 앱 (Dock 아이콘 없음)
        NSApp.setActivationPolicy(.accessory)
    }
}
