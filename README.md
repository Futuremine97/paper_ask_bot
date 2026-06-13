# Paper Assist

화면을 캡처하면 **Claude Sonnet / Claude Opus / ChatGPT 5.5 Pro** 중 선택한 모델이 분석해 주는 macOS 메뉴바 앱입니다. 논문·문서 요약, 수식/그래프 해석, 번역, 코드 분석, 자유 질문에 사용할 수 있습니다.

## 주요 기능

- 메뉴바 상주 앱 (Dock 아이콘 없음)
- 영역 드래그 선택 캡처 또는 전체 화면 캡처
- 전역 단축키 **⌃⇧A** (Control+Shift+A) 로 어디서든 영역 캡처 & 분석
- 모델 선택 (Claude Sonnet · Claude Opus · ChatGPT 5.5 Pro)
- **구독(웹) 모드**: API 키 없이 기존 Claude Pro / ChatGPT Plus 구독으로 사용 (캡처 → 이미지 자동 복사 → 웹 채팅 열림 → ⌘V 붙여넣기)
- **집중모드 다중 선택**: 요약·용어·수식·그래프·번역·코드·비판적 검토·쉽게 설명·핵심 질문·**수식→LaTeX 변환** 칩을 조합하면 프롬프트가 자동 합성
- **후속 질문**: API 모드에서 같은 이미지에 대해 대화를 이어가며 추가 질문 가능
- **결과 히스토리/저장**: 분석 기록을 자동 저장하고, 다시 열거나 Markdown으로 내보내기
- 프롬프트 프리셋 + 직접 입력
- 같은 이미지를 다른 모델/프롬프트로 다시 분석
- API 키는 macOS 키체인에 안전하게 저장

## 요구 사항

- macOS 13 (Ventura) 이상
- Xcode 또는 Command Line Tools (`xcode-select --install`)
- Anthropic / OpenAI API 키

## 실행 방법

### 방법 1 — 터미널에서 바로 실행 (가장 간단)

```bash
cd ~/Documents/mac_paper_assist
./run.sh
```

(또는 `swift run -c release`)

처음 실행 시 의존성 빌드로 수십 초 걸릴 수 있습니다. 실행되면 메뉴바에 돋보기 아이콘이 나타납니다.

### 방법 2 — 더블클릭 실행용 .app 만들기

```bash
cd ~/Documents/mac_paper_assist
./build_app.sh
```

`Paper Assist.app` 이 만들어집니다. Finder 에서 더블클릭하면 실행되고, 메뉴바에 아이콘이 나타납니다. 응용 프로그램 폴더로 옮기려면:

```bash
mv "Paper Assist.app" /Applications/
```

> 처음 실행 시 “확인되지 않은 개발자” 경고가 뜨면, 앱을 우클릭 ▸ **열기** 를 한 번 선택하면 이후로는 그냥 실행됩니다.

### 방법 3 — Xcode 에서 열기

```bash
cd ~/Documents/mac_paper_assist
open Package.swift
```

Xcode 가 열리면 ▶︎ (Run) 버튼으로 실행합니다.

## 처음 설정

1. 메뉴바 아이콘 ▸ **설정…** 클릭
2. **Anthropic API 키**, **OpenAI API 키** 입력 (사용할 것만 입력해도 됩니다)
3. 필요하면 **모델 ID** 를 실제 API 모델명으로 수정
   - 기본값: `claude-sonnet-4-6`, `claude-opus-4-8`, `gpt-5.5-pro`
   - API 제공자의 최신 모델 ID와 다르면 여기서 바꿔 주세요.

## 사용법

1. 메뉴바 아이콘 ▸ **영역 캡처 & 분석** (또는 단축키 **⌃⇧A**)
2. 분석할 화면 영역을 드래그로 선택
3. 선택한 모델이 프롬프트와 함께 이미지를 분석해 결과를 표시
4. **복사** 버튼으로 결과를 클립보드에 복사

## 권한

처음 캡처할 때 macOS가 **화면 기록(Screen Recording)** 권한을 요청합니다.
`시스템 설정 ▸ 개인정보 보호 및 보안 ▸ 화면 기록` 에서 Paper Assist(터미널에서 실행한 경우 터미널)를 허용한 뒤 앱을 다시 실행하세요.

## 모델 ID 참고

앱은 입력한 모델 ID를 그대로 API에 전달합니다. 제공자가 모델명을 바꾸면 **설정 ▸ 모델 ID** 에서 최신 값으로 업데이트하면 됩니다.

- Anthropic: `https://api.anthropic.com/v1/messages`
- OpenAI: `https://api.openai.com/v1/chat/completions`

## 파일 구조

```
mac_paper_assist/
├── Package.swift              # Swift Package 정의
├── run.sh                     # 빌드 & 실행 스크립트
├── README.md
└── Sources/PaperAssist/
    ├── PaperAssistApp.swift   # 앱 진입점 + 메뉴바
    ├── AppState.swift         # 상태 / 캡처·분석 로직
    ├── AIModel.swift          # 모델 정의 + 프리셋
    ├── AIClient.swift         # Anthropic / OpenAI API 호출
    ├── ScreenshotManager.swift# 화면 캡처
    ├── HotKeyCenter.swift     # 전역 단축키
    ├── KeychainStore.swift    # API 키 저장
    ├── MainWindowController.swift # 분석 창
    ├── ContentView.swift      # 메인 UI
    └── SettingsView.swift     # 설정 UI
```
