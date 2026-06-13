import Foundation

/// 분석 세션 히스토리를 JSON 파일로 저장/로드하고 Markdown 으로 내보냅니다.
enum HistoryStore {

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("PaperAssist", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    static func load() -> [AnalysisSession] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([AnalysisSession].self, from: data)) ?? []
    }

    static func save(_ sessions: [AnalysisSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: fileURL)
    }

    /// 세션 하나를 Markdown 문자열로 변환합니다.
    static func markdown(for session: AnalysisSession) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        var out = "# \(session.title)\n\n"
        out += "- 일시: \(df.string(from: session.date))\n"
        out += "- 모델: \(session.modelName)\n\n---\n\n"
        for m in session.messages {
            let who = m.role == .user ? "🙋 질문" : "🤖 분석"
            out += "## \(who)\n\n"
            if m.imageBase64 != nil { out += "_(캡처 이미지 포함)_\n\n" }
            out += m.text + "\n\n"
        }
        return out
    }
}
