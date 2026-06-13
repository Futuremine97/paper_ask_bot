import SwiftUI
import AppKit
import Carbon

@MainActor
final class AppState: ObservableObject {
    // 모델 / 선택
    @Published var models: [AIModel]
    @Published var selectedModelID: String

    // 입력 (집중모드 + 프롬프트)
    @Published var prompt: String
    @Published var selectedModeIDs: Set<String>
    @Published var extraRequest: String

    // 대화 / 결과
    @Published var conversation: [ChatMessage] = []
    @Published var followUpText: String = ""
    @Published var result: String = ""          // 웹 모드 안내문 등
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastImage: NSImage?

    // 히스토리
    @Published var sessions: [AnalysisSession] = []
    private var currentSessionID: UUID?

    // 설정 / API 키
    @Published var anthropicKey: String { didSet { Keychain.set(anthropicKey, for: "anthropic") } }
    @Published var openaiKey: String { didSet { Keychain.set(openaiKey, for: "openai") } }
    @Published var hotKeyEnabled: Bool { didSet { defaults.set(hotKeyEnabled, forKey: "hotKeyEnabled"); applyHotKey() } }

    // UI 상태
    @Published var showSettings: Bool = false
    @Published var showHistory: Bool = false

    private let defaults = UserDefaults.standard
    private var hotKeyID: UInt32?
    private var lastImageB64: String?

    var currentModel: AIModel? {
        models.first { $0.id == selectedModelID } ?? models.first
    }

    init() {
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
        self.sessions = HistoryStore.load()

        applyHotKey()
    }

    // MARK: - 영속화

    func persistSelection() { defaults.set(selectedModelID, forKey: "selectedModelID") }
    func persistPrompt()    { defaults.set(prompt, forKey: "prompt") }
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

    // MARK: - 집중모드

    func toggleMode(_ id: String) {
        if selectedModeIDs.contains(id) { selectedModeIDs.remove(id) }
        else { selectedModeIDs.insert(id) }
        recomposePrompt()
    }

    func isModeOn(_ id: String) -> Bool { selectedModeIDs.contains(id) }

    func recomposePrompt() {
        prompt = FocusMode.compose(modeIDs: selectedModeIDs, extra: extraRequest)
        defaults.set(Array(selectedModeIDs), forKey: "selectedModeIDs")
        defaults.set(extraRequest, forKey: "extraRequest")
        persistPrompt()
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

    // MARK: - 클립보드

    func copyPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
    }

    func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - 캡처 & 분석

    func captureAndAnalyze(mode: CaptureMode) {
        Task { await performCapture(mode: mode) }
    }

    private func performCapture(mode: CaptureMode) async {
        errorMessage = nil
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
        lastImageB64 = png.base64EncodedString()

        guard let model = currentModel else { return }
        if model.mode == .web {
            openWebChat(model: model, png: png)
        } else {
            startNewAnalysis()
        }
    }

    /// 마지막 캡처 이미지를 현재 모델/프롬프트로 다시 분석(새 세션 시작)
    func reanalyzeLast() {
        guard lastImageB64 != nil else {
            errorMessage = "다시 분석할 이미지가 없습니다."
            return
        }
        guard let model = currentModel, model.mode == .api else { return }
        startNewAnalysis()
    }

    /// 새 대화 시작: 이미지 + 현재 프롬프트로 첫 메시지 구성 후 호출
    private func startNewAnalysis() {
        guard let b64 = lastImageB64 else { return }
        result = ""
        showHistory = false
        currentSessionID = UUID()
        conversation = [ChatMessage(role: .user, text: prompt, imageBase64: b64)]
        Task { await runCompletion() }
    }

    /// 후속 질문 전송
    func sendFollowUp() {
        let q = followUpText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !conversation.isEmpty else { return }
        conversation.append(ChatMessage(role: .user, text: q))
        followUpText = ""
        Task { await runCompletion() }
    }

    /// 현재 대화를 API에 보내 응답을 받아 추가
    private func runCompletion() async {
        guard let model = currentModel, model.mode == .api else { return }
        let key = apiKey(for: model.provider)
        guard !key.isEmpty else {
            errorMessage = "\(model.provider.displayName) API 키가 설정되지 않았습니다."
            showSettings = true
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let text = try await AIClient.complete(model: model, apiKey: key, messages: conversation)
            conversation.append(ChatMessage(role: .assistant, text: text))
            saveCurrentToHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 구독(웹) 모드

    private func openWebChat(model: AIModel, png: Data) {
        conversation = []
        if let img = NSImage(data: png) {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([img])
        }
        let urlString = model.provider == .anthropic ? "https://claude.ai/new" : "https://chatgpt.com/"
        if let url = URL(string: urlString) { NSWorkspace.shared.open(url) }
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

    // MARK: - 히스토리

    private func saveCurrentToHistory() {
        guard !conversation.isEmpty else { return }
        let id = currentSessionID ?? UUID()
        currentSessionID = id
        let session = AnalysisSession(id: id, date: Date(),
                                      modelName: currentModel?.displayName ?? "",
                                      messages: conversation)
        if let idx = sessions.firstIndex(where: { $0.id == id }) {
            sessions[idx] = session
        } else {
            sessions.insert(session, at: 0)
        }
        HistoryStore.save(sessions)
    }

    func loadSession(_ session: AnalysisSession) {
        conversation = session.messages
        currentSessionID = session.id
        result = ""
        errorMessage = nil
        showHistory = false
        if let b64 = session.messages.first(where: { $0.imageBase64 != nil })?.imageBase64,
           let data = Data(base64Encoded: b64) {
            lastImage = NSImage(data: data)
            lastImageB64 = b64
        }
    }

    func deleteSession(_ session: AnalysisSession) {
        sessions.removeAll { $0.id == session.id }
        HistoryStore.save(sessions)
        if currentSessionID == session.id {
            currentSessionID = nil
            conversation = []
        }
    }

    func clearConversation() {
        conversation = []
        currentSessionID = nil
        result = ""
        errorMessage = nil
    }

    /// 세션을 Markdown 파일로 내보내기 (저장 위치는 사용자가 선택)
    func exportSession(_ session: AnalysisSession) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "PaperAssist_\(session.title).md"
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            let md = HistoryStore.markdown(for: session)
            try? md.data(using: .utf8)?.write(to: url)
        }
    }
}
