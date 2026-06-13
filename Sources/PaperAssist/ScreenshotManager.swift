import AppKit

/// macOS 기본 `screencapture` 도구를 사용해 화면을 캡처합니다.
/// 이 함수들은 블로킹이므로 백그라운드 스레드에서 호출해야 합니다.
enum ScreenshotManager {

    /// 영역 드래그 선택 캡처. 사용자가 취소하면 nil 을 반환합니다.
    static func captureInteractive() -> Data? {
        run(arguments: ["-i", "-x"])
    }

    /// 전체 화면 캡처.
    static func captureFullScreen() -> Data? {
        run(arguments: ["-x"])
    }

    private static func run(arguments: [String]) -> Data? {
        let tmpPath = NSTemporaryDirectory() + "paperassist_\(UUID().uuidString).png"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments + [tmpPath]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let url = URL(fileURLWithPath: tmpPath)
        defer { try? FileManager.default.removeItem(at: url) }

        // 사용자가 ESC 로 취소하면 파일이 생성되지 않습니다.
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            return nil
        }
        return data
    }
}
