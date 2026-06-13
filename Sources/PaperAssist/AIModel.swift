import Foundation

/// 지원하는 AI 제공자
enum AIProvider: String, Codable, CaseIterable {
    case anthropic
    case openai
    case ollama

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openai: return "OpenAI (ChatGPT)"
        case .ollama: return "Ollama (로컬)"
        }
    }

    /// API 키가 필요한 제공자인지
    var needsAPIKey: Bool {
        switch self {
        case .anthropic, .openai: return true
        case .ollama: return false
        }
    }
}

/// 모델 접근 방식
enum AccessMode: String, Codable {
    case api   // API 키로 직접 호출
    case web   // 구독(웹) — 브라우저에서 사용
}

/// 분석에 사용할 모델 정의
struct AIModel: Identifiable, Hashable, Codable {
    var id: String          // API 모델 ID (설정에서 수정 가능)
    var displayName: String // 화면에 표시되는 이름
    var provider: AIProvider
    var mode: AccessMode = .api

    /// 기본 모델 목록. 모델 ID는 설정 화면에서 변경할 수 있습니다.
    static let defaults: [AIModel] = [
        // API 키 사용
        AIModel(id: "claude-sonnet-4-6", displayName: "Claude Sonnet (API)", provider: .anthropic, mode: .api),
        AIModel(id: "claude-opus-4-8", displayName: "Claude Opus (API)", provider: .anthropic, mode: .api),
        AIModel(id: "gpt-5.5-pro", displayName: "ChatGPT 5.5 Pro (API)", provider: .openai, mode: .api),
        // 구독(웹) 사용 — API 키 불필요
        AIModel(id: "web-claude", displayName: "Claude (구독·웹)", provider: .anthropic, mode: .web),
        AIModel(id: "web-chatgpt", displayName: "ChatGPT (구독·웹)", provider: .openai, mode: .web),
        // 로컬 Ollama — API 키 불필요 (비전 모델 필요: ollama pull llava)
        AIModel(id: "llava", displayName: "Ollama (llava · 로컬)", provider: .ollama, mode: .api)
    ]
}

/// 캡처 방식
enum CaptureMode {
    case interactive   // 영역 드래그 선택
    case fullScreen    // 전체 화면
}

/// 대화 메시지 (후속 질문을 위한 컨텍스트)
struct ChatMessage: Identifiable, Codable, Hashable {
    enum Role: String, Codable { case user, assistant }
    var id = UUID()
    var role: Role
    var text: String
    var imageBase64: String? = nil   // 첫 사용자 메시지에만 이미지 포함
    var date: Date = Date()
}

/// 저장된 분석 세션 (히스토리)
struct AnalysisSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var date = Date()
    var modelName: String
    var messages: [ChatMessage]

    /// 첫 사용자 메시지에서 제목 추출
    var title: String {
        let firstUser = messages.first(where: { $0.role == .user })?.text ?? "분석"
        let line = firstUser.split(separator: "\n").first.map(String.init) ?? firstUser
        return line.count > 40 ? String(line.prefix(40)) + "…" : line
    }
}

/// 집중모드 — 여러 개를 동시에 켜면 프롬프트가 그 조합으로 합성됩니다.
struct FocusMode: Identifiable, Hashable {
    let id: String
    let name: String
    let fragment: String   // 합성 시 프롬프트에 들어갈 문구

    static let all: [FocusMode] = [
        FocusMode(id: "summary",   name: "핵심 요약",     fragment: "전체 내용을 핵심 위주로 간결하게 요약"),
        FocusMode(id: "detail",    name: "자세한 설명",   fragment: "내용을 단계별로 자세히 풀어서 설명"),
        FocusMode(id: "terms",     name: "용어 풀이",     fragment: "어려운 전문 용어를 쉽게 정의하고 설명"),
        FocusMode(id: "math",      name: "수식 해석",     fragment: "수식의 각 기호 의미와 직관적 의미를 해석"),
        FocusMode(id: "figure",    name: "그래프/표",     fragment: "그래프·표·그림이 나타내는 의미를 해석"),
        FocusMode(id: "latex",     name: "수식→LaTeX",    fragment: "이미지의 모든 수식을 정확한 LaTeX 코드로 변환해 코드블록(```)으로 제시(인라인은 $...$, 별도 식은 $$...$$ 사용)"),
        FocusMode(id: "translate", name: "한국어 번역",   fragment: "텍스트를 자연스러운 한국어로 번역(전문 용어는 원어 병기)"),
        FocusMode(id: "code",      name: "코드 분석",     fragment: "코드의 동작을 단계별로 설명하고 버그·개선점을 지적"),
        FocusMode(id: "critique",  name: "비판적 검토",   fragment: "주장의 가정·한계·반론·약점을 비판적으로 검토"),
        FocusMode(id: "eli5",      name: "쉽게 설명",     fragment: "비전공자도 이해할 수 있도록 쉬운 비유로 설명"),
        FocusMode(id: "questions", name: "핵심 질문",     fragment: "내용을 더 깊이 이해하기 위한 핵심 질문을 제시")
    ]

    /// 선택된 모드 + 추가 요청으로 최종 프롬프트를 합성합니다.
    static func compose(modeIDs: Set<String>, extra: String) -> String {
        let selected = all.filter { modeIDs.contains($0.id) }
        var p: String
        if selected.isEmpty {
            p = "이 이미지를 분석해서 핵심 내용을 한국어로 명확하게 설명해 주세요."
        } else {
            p = "이 이미지를 분석해 주세요. 특히 아래 항목에 집중해 주세요:\n"
            p += selected.map { "- \($0.fragment)" }.joined(separator: "\n")
            p += "\n모두 한국어로 답변해 주세요."
        }
        let e = extra.trimmingCharacters(in: .whitespacesAndNewlines)
        if !e.isEmpty { p += "\n\n추가 요청: \(e)" }
        return p
    }
}
