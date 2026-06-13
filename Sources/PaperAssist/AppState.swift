import SwiftUI
import AppKit
import Carbon

@MainActor
final class AppState: ObservableObject {
    // 모델 / 선택
    @Published var models: [AIModel]
    @Published var selectedModelID: String

    // 입력 / 결과
    @Published var prompt: String
    @Published var selectedModeIDs: Set<String>
    @Published var extraRequest: String
    @Published var result: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastImage: NSImage?

    // 설정
    @Published var anthropicKey: String { didSet { Keychain.set(anthropicKey, for: "anthropic") } }
    @Published var openaiKey: String { didSet { Keychain.set(openaiKey, for: "openai") } }
    @Published var hotKeyEnabled: Bool { didSet { defaults.set(hotKeyEnabled, forKey: "hotKeyEnabled"); applyHotKey() } }

    // UI 상태
    @Published var showSettings: Bool = false

    private let defaults = UserDefaults.standard
    private var hotKeyID: UInt32?

    var currentModel: AIModel? {
        models.first { $0.id == selectedModelID } ?? models.first
    }

    init() {
        // 모델 ID 오버라이드 로드 (설정에서 변경한 값)
        var loaded = AIModel.defaults
        if let data = defaults.data(forKey: "modelOverrides"),
           let saved = try? JSONDecoder().decode([AIModel].self, from: data),
           saved.count == loaded.count {
            loaded = saved
        }
        self.models = loaded
        self.selectedModelID = defaults.string(forKey: "selectedModelID") ?? loaded.first?.id ?? ""
        let savedModes = Set(defaults.stringArray(forKey: "selectedModeIDs") ?? ["summary", "terms"])
        let savedExtra = defaults.string(forKey: "extraRequest") ?? ""
        self.selectedModeIDs = savedModes
        self.extraRequest = savedExtra
        self.prompt = FocusMode.compose(modeIDs: savedModes, extra: savedExtra)
        self.anthropicKey = Keychain.get("anthropic")
        self.openaiKey = Keychain.get("openai")
        self.hotKeyEnabled = defaults.object(forKey: "hotKeyEnabled") as? Bool ?? true

        applyHotKey()
    }

    // MARK: - 영속화

    func persistSelection() {
        defaults.set(selectedModelID, forKey: "selectedModelID")
    }

    func persistPrompt() {
        defaults.set(prompt, forKey: "prompt")
    }

    // MARK: - 집중모드

    func toggleMode(_ id: String) {
        if selectedModeIDs.contains(id) {
            selectedModeIDs.remove(id)
        } else {
            selectedModeIDs.insert(id)
        }
        recomposePrompt()
    }

    func isModeOn(_ id: String) -> Bool {
        selectedModeIDs.contains(id)
    }

    /// 선택된 집중모드 + 추가 요청으로 프롬프트를 다시 만듭니다.
    func recomposePrompt() {
        prompt = FocusMode.compose(modeIDs: selectedModeIDs, extra: extraRequest)
        defaults.set(Array(selectedModeIDs), forKey: "selectedModeIDs")
        defaults.set(extraRequest, forKey: "extraRequest")
        persistPrompt()
    }

    func persistModels() {
        if let data = try? JSONEncoder().encode(models) {
            defaults.set(data, forKey: "modelOverrides")
        }
    }

    func apiKey(for provider: AIProvider) -> String {
        switch provider {
        case .anthropic: return anthropicKey
        case .openai: return openaiKey
        }
    }

    // MARK: - 전역 단축키 (⌃⇧A)

    private func applyHotKey() {
        if let id = hotKeyID {
            HotKeyCenter.shared.unregister(id)
            hotKeyID = nil
        }
        guard hotKeyEnabled else { return }
        let mods = UInt32(controlKey | shiftKey)
        hotKeyID = HotKeyCenter.shared.register(keyCode: UInt32(kVK_ANSI_A), modifiers: mods) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                MainWindowController.shared.show(state: self)
                self.captureAndAnalyze(mode: .interactive)
            }
        }
    }

    // MARK: - 캡처 & 분석

    func captureAndAnalyze(mode: CaptureMode) {
        Task { await performCapture(mode: mode) }
    }

    private func performCapture(mode: CaptureMode) async {
        errorMessage = nil
        // screencapture 는 블로킹이므로 백그라운드에서 실행
        let png: Data? = await Task.detached(priority: .userInitiated) {
            switch mode {
            case .interactive: return ScreenshotManager.captureInteractive()
            case .fullScreen:  return ScreenshotManager.captureFullScreen()
            }
        }.value

        guard let png else {
            errorMessage = "캡처가 취소되었거나 실패했습니다."
            return
        }
        lastImage = NSImage(data: png)
        await analyze(png)
    }

    func reanalyzeLast() {
        guard let image = lastImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            errorMessage = "다시 분석할 이미지가 없습니다."
            return
        }
        Task { await analyze(png) }
    }

    /// 프롬프트를 클립보드에 복사 (구독·웹 모드에서 사용)
    func copyPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
    }

    /// 구독(웹) 모드: 이미지를 클립보드에 복사하고 해당 챗 사이트를 엽니다.
    private func openWebChat(model: AIModel, png: Data) {
        if let img = NSImage(data: png) {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([img])
        }
        let urlString = model.provider == .anthropic ? "https://claude.ai/new" : "https://chatgpt.com/"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        let site = model.provider == .anthropic ? "Claude" : "ChatGPT"
        isLoading = false
        errorMessage = nil
        result = """
        ✅ 스크린샷을 클립보드에 복사하고 \(site) 웹페이지를 열었습니다.

        구독 계정으로 분석하는 방법
        1) 열린 \(site) 채팅 입력창을 클릭하세요.
        2) ⌘V 로 방금 캡처한 이미지를 붙여넣으세요.
        3) 아래 ‘프롬프트 복사’ 버튼을 누른 뒤, 입력창에 ⌘V 로 붙여넣고 전송하세요.

        ※ 구독(Claude Pro / ChatGPT Plus)에는 공식 API가 없어, 이렇게 웹에서 직접 사용합니다. API 키가 필요 없습니다.
        """
    }

    private func analyze(_ png: Data) async {
        guard let model = currentModel else { return }

        // 구독(웹) 모드는 API 호출 대신 브라우저로 연결
        if model.mode == .web {
            openWebChat(model: model, png: png)
            return
        }

        let key = apiKey(for: model.provider)
        guard !key.isEmpty else {
            errorMessage = "\(model.provider.displayName) API 키가 설정되지 않았습니다."
            showSettings = true
            return
        }
        isLoading = true
        result = ""
        errorMessage = nil
        defer { isLoading = false }
        do {
            let text = try await AIClient.analyze(model: model, apiKey: key, prompt: prompt, imagePNG: png)
            result = text
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
