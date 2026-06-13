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
            } else {
                analyzeView
            }
        }
        .frame(minWidth: 420, minHeight: 560)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundStyle(.tint)
            Text("Paper Assist")
                .font(.headline)
            Spacer()
            Button {
                state.showSettings.toggle()
            } label: {
                Image(systemName: state.showSettings ? "xmark.circle" : "gearshape")
            }
            .buttonStyle(.borderless)
            .help(state.showSettings ? "닫기" : "설정")
        }
        .padding(12)
    }

    // MARK: - Analyze View

    private var analyzeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 모델 선택
            VStack(alignment: .leading, spacing: 4) {
                Text("모델").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $state.selectedModelID) {
                    ForEach(state.models) { model in
                        Text(model.displayName).tag(model.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .onChange(of: state.selectedModelID) { _ in state.persistSelection() }
                if state.currentModel?.mode == .web {
                    Text("구독 모드: 캡처하면 이미지를 클립보드에 복사하고 웹 채팅을 엽니다 (API 키 불필요).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // 집중모드 (다중 선택)
            VStack(alignment: .leading, spacing: 4) {
                Text("집중모드 (여러 개 선택 가능)").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(FocusMode.all) { mode in
                        let on = state.isModeOn(mode.id)
                        Button {
                            state.toggleMode(mode.id)
                        } label: {
                            Text(mode.name)
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.borderless)
                        .background(on ? Color.accentColor : Color.secondary.opacity(0.12))
                        .foregroundStyle(on ? Color.white : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
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

            // 최종 프롬프트 (자동 합성 · 직접 수정 가능)
            VStack(alignment: .leading, spacing: 4) {
                Text("최종 프롬프트").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $state.prompt)
                    .font(.body)
                    .frame(height: 76)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                    .onChange(of: state.prompt) { _ in state.persistPrompt() }
            }

            // 캡처 버튼
            HStack(spacing: 8) {
                Button {
                    state.captureAndAnalyze(mode: .interactive)
                } label: {
                    Label(state.currentModel?.mode == .web ? "영역 캡처 & 웹으로 보내기" : "영역 캡처 & 분석",
                          systemImage: "crop")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isLoading)

                Button {
                    state.captureAndAnalyze(mode: .fullScreen)
                } label: {
                    Image(systemName: "macwindow")
                }
                .help("전체 화면 캡처")
                .disabled(state.isLoading)

                Button {
                    state.reanalyzeLast()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("같은 이미지를 현재 모델/프롬프트로 다시 분석")
                .disabled(state.isLoading || state.lastImage == nil)
            }

            Divider()

            // 결과
            resultArea
        }
        .padding(12)
    }

    private var resultArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("결과").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if state.currentModel?.mode == .web {
                    Button {
                        state.copyPrompt()
                    } label: {
                        Label("프롬프트 복사", systemImage: "text.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                if !state.result.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(state.result, forType: .string)
                    } label: {
                        Label("복사", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }

            if let thumb = state.lastImage {
                Image(nsImage: thumb)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 90)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
            }

            ScrollView {
                if state.isLoading {
                    HStack {
                        ProgressView()
                        Text("분석 중…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
                } else if let error = state.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if state.result.isEmpty {
                    Text("화면 영역을 캡처하면 선택한 모델이 분석해 드립니다.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                } else {
                    Text(state.result)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
