# CC Pocket

**에이전트를 주머니에.**

휴대폰 채팅처럼 Codex와 Claude를 사용하세요. 작업을 요청하고, 다음 단계를 승인하고,
결과를 확인하세요. 태블릿이나 Mac에서도 같은 작업을 이어갈 수 있습니다.

[CC Pocket 둘러보기](https://k9i-0.github.io/ccpocket/install/?lang=ko) · 무료 사용 · 오픈 소스

[English README](README.md) | [日本語 README](README.ja.md) | [简体中文 README](README.zh-CN.md)

<p align="center">
  <img src="docs/images/screenshots-ko.png" alt="CC Pocket 스크린샷" width="800">
</p>

## 설치

1. 세션을 실행할 머신에 에이전트 CLI를 하나 이상 설치합니다:
   [Codex](https://github.com/openai/codex) 또는 [Claude](https://docs.anthropic.com/en/docs/claude-code).
2. 같은 머신에 [Node.js](https://nodejs.org/) 20.18.1 이상을 설치합니다.
3. CC Pocket Bridge Server를 시작합니다.

```bash
npx @ccpocket/bridge@latest
```

4. CC Pocket을 설치하고 Bridge Server가 출력한 QR 코드를 스캔합니다.
5. 프로젝트를 선택하고 Codex 또는 Claude를 고른 뒤 앱에서 세션을 시작합니다.

| 플랫폼 | 설치 |
|--------|------|
| **iOS / iPadOS** | <a href="https://apps.apple.com/us/app/cc-pocket-code-anywhere/id6759188790"><img height="40" alt="App Store에서 다운로드" src="docs/images/app-store-badge.svg" /></a> |
| **Android** | <a href="https://play.google.com/store/apps/details?id=com.k9i.ccpocket"><img height="40" alt="Google Play에서 받기" src="docs/images/google-play-badge-en.svg" /></a> |
| **macOS** | 최신 `.dmg`는 [GitHub Releases](https://github.com/K9i-0/ccpocket/releases?q=macos)에서 다운로드할 수 있습니다. `macos/v*` 태그가 붙은 릴리스를 찾으세요. Homebrew Cask를 사용해 `brew install --cask cc-pocket` 명령으로 설치할 수도 있습니다. |
| **Linux(실험적)** | 최신 `.tar.gz`는 [GitHub Releases](https://github.com/K9i-0/ccpocket/releases?q=linux)에서 다운로드할 수 있습니다. `linux/v*` 태그가 붙은 릴리스를 찾으세요. 커뮤니티에서 관리하는 [AUR 패키지](https://aur.archlinux.org/packages/cc-pocket-bin)를 `yay -S cc-pocket-bin`으로 설치할 수도 있습니다. |
| **Windows(실험적)** | 최신 `.zip`은 [GitHub Releases](https://github.com/K9i-0/ccpocket/releases?q=windows)에서 다운로드할 수 있습니다. `windows/v*` 태그가 붙은 릴리스를 찾으세요. |

## 무료로 사용할 수 있습니다

CC Pocket은 무료로 사용할 수 있습니다. 개발 워크플로에 도움이 된다면 앱 안에서 Supporter가 되어 주세요. Supporter 구매는 AI 도구 비용을 감당하고 지속적인 개발을 이어가는 데 사용됩니다.

## 할 수 있는 일

- **채팅처럼 조작.** 세션마다 요청, 응답, 승인, 질문이 하나의 대화방에 모입니다. Markdown, 음성 입력, 이미지 첨부도 지원합니다.
- **기기를 바꿔도 이어서.** CLI나 앱의 세션을 휴대폰, 태블릿, Mac에서 다시 여세요. 큰 화면에서는 채팅, 파일, Git 변경 내용을 나란히 볼 수 있습니다.
- **연결이 끊겨도 입력은 유지.** 오프라인 메시지를 보관했다가 재연결 후 자동 전송하고, 놓친 응답도 복구합니다. 새 요청을 실행하려면 연결이 필요합니다.
- **만들고, 보고, 재생.** Codex Imagegen으로 이미지를 만들고 채팅에서 확인하세요. 동영상과 오디오 파일도 앱 안에서 재생할 수 있습니다.
- **검토부터 반영까지.** 파일 탐색, 코드·이미지 diff, stage, commit, push, revert를 지원합니다. 병렬 작업은 git worktree로 분리할 수 있습니다.
- **내 컴퓨터에서 실행.** Mac, Linux, Windows의 Bridge Server로 에이전트를 실행합니다. QR 코드, 저장된 호스트, Tailscale로 연결하고 SSH로 Bridge를 관리하세요.

## 작동 방식

CC Pocket은 두 부분으로 구성됩니다.

```text
CC Pocket app  <->  사용자의 머신에서 실행되는 Bridge Server  <->  Codex / Claude
```

앱은 조작 화면입니다. Bridge Server는 프로젝트, shell, git 저장소, 에이전트 CLI에 접근할 수 있는
사용자의 머신에서 실행됩니다. 코드는 호스팅 IDE로 옮기지 않고 자신의 머신에 그대로 둡니다.

## 원격 접속

같은 네트워크에서는 QR 코드, mDNS 자동 검색, 또는 직접 입력한 `ws://` / `wss://` URL로 연결할 수 있습니다.

집이나 사무실 밖에서 접속하려면 Tailscale 사용을 권장합니다.

1. 호스트 머신과 휴대폰에 [Tailscale](https://tailscale.com/)을 설치합니다
2. 같은 tailnet에 참여합니다
3. CC Pocket에서 `ws://<host-tailscale-ip>:8765`로 연결합니다

항상 켜두는 호스트라면 Bridge Server를 백그라운드 서비스로 등록할 수도 있습니다.

```bash
npx @ccpocket/bridge@1 setup
```

서비스 설정은 macOS launchd와 Linux systemd를 지원합니다.
`BRIDGE_ALLOWED_DIRS` 같은 Bridge 설정과 service setup이 저장하는 항목은
[Bridge package README](packages/bridge/README.md#configuration)를 참고하세요.

## 참고

- Claude 세션은 기본적으로 `ANTHROPIC_API_KEY`를 사용합니다. 공식 문서가 이 구조에
  어떻게 적용되는지 명확하지 않으므로 구독 인증은 Bridge에서
  `BRIDGE_ALLOW_CLAUDE_OAUTH=1`로 명시적으로 활성화해야 합니다.
  자세한 내용은 [Claude 인증 문제 해결](docs/auth-troubleshooting.ko.md)을 확인하세요.
- CC Pocket은 셀프 호스팅과 최소한의 데이터 수집을 전제로 설계되었습니다. Supporter 구매는
  같은 Apple ID / Google 계정 안에서 복원할 수 있지만, 스토어 간에는 공유되지 않습니다.
  자세한 내용은 [Supporter / Purchases](docs/supporter_ko.md)를 확인하세요.
- macOS 스크린샷 캡처에는 Bridge Server를 실행하는 터미널 앱에 화면 기록 권한이 필요합니다.
- CC Pocket은 Anthropic 또는 OpenAI와 제휴, 보증 또는 공식 관계가 없습니다.

## 개발

```bash
git clone https://github.com/K9i-0/ccpocket.git
cd ccpocket
npm install
cd apps/mobile && flutter pub get && cd ../..
```

자주 쓰는 명령:

| 명령 | 설명 |
|------|------|
| `npm run bridge` | Bridge Server를 개발 모드로 시작 |
| `npm run bridge:build` | Bridge Server 빌드 |
| `npm run dev` | Bridge를 재시작하고 Flutter 앱 실행 |
| `npm run test:bridge` | Bridge Server 테스트 실행 |
| `cd apps/mobile && flutter test` | Flutter 테스트 실행 |
| `cd apps/mobile && dart analyze` | Dart 정적 분석 실행 |

기여 방법은 [CONTRIBUTING.md](CONTRIBUTING.md)를 확인하세요.

## 라이선스

[MIT](LICENSE)
