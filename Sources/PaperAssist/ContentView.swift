import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if state.showSettings {
                SettingsView()
            } else if state.showHistory {
                HistoryView()
            } else {
                analyzeView
            }
        }
        .frame(minWidth: 380, minHeight: 480)
        .tint(.primary)   // 미니멀 흑백: 모든 강조색을 흑/백으로
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "viewfinder").foregroundStyle(.primary)
            Text("Paper Assist").font(.headline)
            Spacer()
            Button {
                state.showHistory.toggle()
                state.showSettings = false
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .buttonStyle(.borderless)
            .help("기록")

            Button {
                state.showSettings.toggle()
                state.showHistory = false
            } label: {
                Image(systemName: state.showSettings ? "xmark.circle" : "gearshape")
            }
            .buttonStyle(.borderless)
            .help("설정")
        }
        .padding(12)
    }

    // MARK: - Analyze

    private var analyzeView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    controls
                    Divider()
                    conversationArea
                }
                .padding(12)
            }
            if showFollowUp {
                Divider()
                followUpBar
            }
        }
    }

    private var showFollowUp: Bool {
        state.currentModel?.mode == .api && !state.conversation.isEmpty
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 모델
            VStack(alignment: .leading, spacing: 4) {
                Text("모델").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $state.selectedModelID) {
                    ForEach(state.models) { m in Text(m.displayName).tag(m.id) }
                }
                .labelsHidden().pickerStyle(.menu)
                .onChange(of: state.selectedModelID) { _ in state.persistSelection() }
                if state.currentModel?.mode == .web {
                    Text("구독 모드: 캡처하면 이미지를 클립보드에 복사하고 웹 채팅을 엽니다 (API 키 불필요).")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            // 집중모드
            VStack(alignment: .leading, spacing: 4) {
                Text("집중모드 (여러 개 선택 가능)").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(FocusMode.all) { mode in
                        let on = state.isModeOn(mode.id)
                        Button { state.toggleMode(mode.id) } label: {
                            Text(mode.name).font(.caption).frame(maxWidth: .infinity).padding(.vertical, 5)
                        }
                        .buttonStyle(.borderless)
                        .background(on ? Color.primary : Color.secondary.opacity(0.12))
                        .foregroundStyle(on ? Color(nsColor: .windowBackgroundColor) : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(on ? 0 : 0.18)))
                    }
                }
            }

            // 추가 요청
            VStack(alignment: .leading, spacing: 4) {
                Text("추가 요청 (선택)").font(.caption).foregroundStyle(.secondary)
                TextField("예: 표 2의 수치를 중심으로", text: $state.extraRequest)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: state.extraRequest) { _ in state.recomposePrompt() }
            }

            // 최종 프롬프트
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("최종 프롬프트").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if state.currentModel?.mode == .web {
                        Button { state.copyPrompt() } label: {
                            Label("프롬프트 복사", systemImage: "text.badge.plus")
                        }.buttonStyle(.borderless).controlSize(.small)
                    }
                }
                TextEditor(text: $state.prompt)
                    .font(.body).frame(height: 64)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                    .onChange(of: state.prompt) { _ in state.persistPrompt() }
            }

            // 캡처 버튼
            HStack(spacing: 8) {
                Button { state.captureAndAnalyze(mode: .interactive) } label: {
                    Label(state.currentModel?.mode == .web ? "영역 캡처 & 웹으로 보내기" : "영역 캡처 & 분석",
                          systemImage: "crop").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).disabled(state.isLoading)

                Button { state.captureAndAnalyze(mode: .fullScreen) } label: {
                    Image(systemName: "macwindow")
                }.help("전체 화면 캡처").disabled(state.isLoading)

                Button { state.reanalyzeLast() } label: {
                    Image(systemName: "arrow.clockwise")
                }.help("같은 이미지를 다시 분석").disabled(state.isLoading || state.lastImage == nil)
            }
        }
    }

    private var conversationArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("결과").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !state.conversation.isEmpty {
                    Button { state.clearConversation() } label: {
                        Label("새로 시작", systemImage: "trash")
                    }.buttonStyle(.borderless).controlSize(.small)
                }
            }

            if let thumb = state.lastImage, !state.conversation.isEmpty {
                Image(nsImage: thumb).resizable().scaledToFit().frame(maxHeight: 80)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
            }

            if state.isLoading && state.conversation.count <= 1 {
                loadingRow
            }

            if !state.conversation.isEmpty {
                ForEach(state.conversation) { msg in
                    messageBubble(msg)
                }
                if state.isLoading && state.conversation.count > 1 {
                    loadingRow
                }
            } else if let error = state.errorMessage {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if !state.result.isEmpty {
                Text(state.result).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("화면 영역을 캡처하면 선택한 모델이 분석해 드립니다.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            }

            if !state.conversation.isEmpty, let error = state.errorMessage {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var loadingRow: some View {
        HStack { ProgressView(); Text("분석 중…").foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 12)
    }

    private func messageBubble(_ msg: ChatMessage) -> some View {
        let isUser = msg.role == .user
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(isUser ? "🙋 질문" : "🤖 분석").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if !isUser {
                    Button { state.copyText(msg.text) } label: {
                        Image(systemName: "doc.on.doc")
                    }.buttonStyle(.borderless).controlSize(.small).help("복사")
                }
            }
            Text(msg.text.isEmpty ? "(이미지)" : msg.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(isUser ? Color.primary.opacity(0.06) : Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var followUpBar: some View {
        HStack(spacing: 8) {
            TextField("후속 질문… (예: 이 부분 더 자세히)", text: $state.followUpText)
                .textFieldStyle(.roundedBorder)
                .disabled(state.isLoading)
                .onSubmit { state.sendFollowUp() }
            Button { state.sendFollowUp() } label: {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.isLoading || state.followUpText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
    }
}

// MARK: - 히스토리 화면

struct HistoryView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.sessions.isEmpty {
                Text("아직 저장된 분석 기록이 없습니다.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(state.sessions) { session in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.title).font(.body).lineLimit(2)
                            HStack(spacing: 8) {
                                Text(session.modelName).font(.caption2).foregroundStyle(.secondary)
                                Text(dateStr(session.date)).font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Button("열기") { state.loadSession(session) }
                                    .buttonStyle(.borderless).controlSize(.small)
                                Button { state.exportSession(session) } label: {
                                    Image(systemName: "square.and.arrow.up")
                                }.buttonStyle(.borderless).controlSize(.small).help("Markdown 내보내기")
                                Button { state.deleteSession(session) } label: {
                                    Image(systemName: "trash")
                                }.buttonStyle(.borderless).controlSize(.small).help("삭제")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func dateStr(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f.string(from: d)
    }
}
