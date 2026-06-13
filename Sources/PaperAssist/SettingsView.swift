import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                // API 키
                section("API 키") {
                    VStack(alignment: .leading, spacing: 10) {
                        keyField(
                            title: "Anthropic API 키",
                            hint: "Claude Sonnet / Opus — console.anthropic.com",
                            text: $state.anthropicKey
                        )
                        keyField(
                            title: "OpenAI API 키",
                            hint: "ChatGPT — platform.openai.com",
                            text: $state.openaiKey
                        )
                        Text("키는 macOS 키체인에 안전하게 저장됩니다.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // 모델 ID (API 모델만)
                section("모델 ID (API)") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach($state.models) { $model in
                            if model.mode == .api {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(model.displayName)  ·  \(model.provider.displayName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextField("모델 ID", text: $model.id)
                                        .textFieldStyle(.roundedBorder)
                                        .onChange(of: model.id) { _ in state.persistModels() }
                                }
                            }
                        }
                        Text("API에서 사용하는 정확한 모델 ID로 바꿀 수 있습니다.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Ollama (로컬)
                section("Ollama (로컬 모델)") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ollama 주소").font(.caption)
                        TextField("http://localhost:11434", text: $state.ollamaHost)
                            .textFieldStyle(.roundedBorder)
                        Text("API 키 없이 로컬에서 실행됩니다. 사용 전 준비:\n1) ollama.com 에서 Ollama 설치\n2) 터미널에서 비전 모델 받기 — 예) ollama pull llava\n3) 모델 선택에서 ‘Ollama (llava · 로컬)’ 선택\n\n모델 ID는 위 ‘모델 ID (API)’ 칸에서 llama3.2-vision 등으로 바꿀 수 있습니다.")
                            .font(.caption2).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // 구독(웹) 모드 안내
                section("구독(웹) 모드") {
                    Text("모델 선택에서 ‘Claude (구독·웹)’ 또는 ‘ChatGPT (구독·웹)’ 를 고르면 API 키 없이 사용할 수 있습니다. 캡처하면 이미지가 클립보드에 복사되고 해당 웹사이트가 열리며, ⌘V 로 붙여넣어 구독 계정으로 분석합니다.\n\n※ Claude Pro / ChatGPT Plus 구독에는 공식 API가 없어 웹에서 직접 사용하는 방식입니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 단축키
                section("전역 단축키") {
                    Toggle(isOn: $state.hotKeyEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("⌃⇧A  로 영역 캡처 & 분석")
                            Text("어느 앱에서든 작동합니다.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // 권한 안내
                section("권한 안내") {
                    Text("처음 캡처할 때 macOS가 ‘화면 기록’ 권한을 요청합니다. 시스템 설정 ▸ 개인정보 보호 및 보안 ▸ 화면 기록에서 Paper Assist(또는 터미널)를 허용해 주세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button("완료") {
                        state.showSettings = false
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Button("Paper Assist 종료") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(14)
        }
    }

    private func keyField(title: String, hint: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption)
            SecureField(hint, text: text)
                .textFieldStyle(.roundedBorder)
            Text(hint).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
