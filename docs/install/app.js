"use strict";

// English is rendered in HTML so the page remains usable without JavaScript.
const english = Object.fromEntries(
  [...document.querySelectorAll("[data-i18n]")].map((el) => [
    el.dataset.i18n,
    el.textContent,
  ]),
);
Object.assign(english, {
  metaTitle: "CC Pocket — Your agents. In your pocket.",
  metaDescription:
    "Control Codex, Claude, and Antigravity from one chat-first app. Track live activity, approve in a tap, review diffs, and pick up the same work on iPad and Mac. Free and open source.",
  copy: "Copy command",
  copied: "Copied to clipboard",
  copyFailed: "Select and copy the command above.",
  close: "Close screenshot",
  zoomChat: "Enlarge chat screenshot",
  zoomApprovals: "Enlarge approval list screenshot",
  zoomRecent: "Enlarge recent sessions screenshot",
  zoomGit: "Enlarge Git review screenshot",
  zoomWorkspace: "Enlarge workspace screenshot",
  zoomNetwork: "Enlarge pending delivery screenshot",
  zoomImagegen: "Enlarge image generation screenshot",
  zoomVideo: "Enlarge video player screenshot",
  zoomAudio: "Enlarge audio player screenshot",
});

const translations = {
  en: english,
  ja: {
    metaTitle: "CC Pocket — エージェントを、ポケットに。",
    metaDescription:
      "Codex・Claude・AntigravityをひとつのチャットUIで。ライブ進捗、ワンタップ承認、Git差分レビュー、iPad・Mac連携まで。無料・オープンソース。",
    skip: "本文へ移動",
    navAgents: "エージェント",
    navWorkflow: "できること",
    navWorkspace: "ワークスペース",
    navSetup: "はじめ方",
    eyebrow: "コーディングエージェントのためのセルフホスト・モバイルクライアント",
    hero1: "エージェントを、",
    hero2: "ポケットに。",
    heroDesc:
      "Codex・Claude・Antigravityを、スマホのためのチャットUIにひとつに統合。指示・承認・差分レビューから、iPadやMacでの続きまでどこからでも。",
    getApp: "CC Pocketを入手",
    quickStart: "はじめ方",
    freeNote: "無料・オープンソース（MIT）。自分のPCのBridge Serverで動作します。",
    artNote: "次の一手は、ワンタップで。",
    platformLead: "スマホが主役。どの画面でも、心地よく。",
    experimental: "試験提供",
    agentsKicker: "01 — 3つのエージェントを、ひとつに",
    agents1: "Codex、Claude、Antigravity。",
    agents2: "ひとつのUIで操る。",
    agentsDesc:
      "3つのエージェントのセッションをひとつの一覧から開始・再開。モデル・思考レベル・承認モードの切り替え、5時間/週間のプラン使用量確認、使うエージェントのオン・オフまで対応しています。",
    agentCodexDesc:
      "Codex CLI・Codex Appのセッションを再開。Planモード切替やCodex Imagegenにも対応。",
    agentClaudeDesc:
      "ライブアクティビティと思考プレビュー、セッション要約カード、対話式の質問フォームに対応。",
    agentAgyDesc:
      "Antigravity CLI（agy）連携。モデル・思考レベル選択、プラン確認、使用量表示、画像生成に対応。",
    experienceKicker: "02 — 移動するあなたのために",
    experience1: "できることは、本格的。",
    experience2: "使い心地は、軽やか。",
    chatTitle: "いつものチャット感覚で。",
    chatDesc:
      "タスクごとにひとつの部屋。思考プレビューや実行中コマンド、バックグラウンド進捗をリアルタイムで確認でき、音声入力・スケッチ添付・Markdown補完にも対応しています。",
    approvalTitle: "次の判断を、ワンタップで。",
    approvalDesc:
      "複数セッションの承認待ちをひとつの一覧に集約。コマンド実行、ファイル編集、MCPリクエスト、実装プランをデスクに戻らず承認できます。",
    gitTitle: "差分を見て、そのまま反映。",
    gitDesc:
      "シンタックスハイライト付きコード差分や画像差分を確認し、行コメントでAIレビュー依頼。stage・commit・push・worktree分離、さらにGitHub Issues / PRsからの開始にも対応。",
    networkTitle: "電波が途切れても、止まらない。",
    networkDesc:
      "圏外や使用量制限に達したときのメッセージはキューで保持し、再接続後・リセット後に自動送信。取りこぼした応答も差分で復元します。",
    desktopKicker: "03 — 同じ作業を、どの画面でも",
    desktop1: "Macを離れても、",
    desktop2: "続きは、その手の中に。",
    desktopDesc:
      "MacやCLIで始めて、iPhone・iPhone Duo・Androidで確認。iPadやデスクトップでは、セッション一覧・チャット・Explorer・Git差分を並べて作業できます。",
    macDownload: "macOS版をダウンロード",
    workspaceCaption: "3ペインのダークワークスペース（画面はiPad版）。",
    desktopExperimental: "Linux・Windows（試験提供）",
    mediaKicker: "04 — コードの、その先まで",
    media1: "つくる。見る。",
    media2: "再生する。",
    mediaDesc:
      "Codex ImagegenやAntigravityで生成した画像をチャットやギャラリーで確認。動画や音声ファイルも、アプリを離れずそのまま再生できます。",
    imageCaption: "生成した画像を、チャットで。",
    videoCaption: "シーク、再生速度、全画面再生まで。",
    audioCaption: "アプリの中で、そのまま試聴。",
    setupKicker: "05 — はじめよう",
    setupTitle: "コマンドひとつで、すぐモバイルへ。",
    setupDesc:
      "PCにNode.js 22.19.0以上と、Codex・Claude・Antigravity（agy）のいずれかをご用意ください。",
    step1: "Bridgeを起動。",
    step1Desc: "エージェントを使うMac・Linux・Windowsマシンで実行します。",
    step2: "QRをスキャン。",
    step2Desc: "CC Pocketを入れて、ターミナルに表示されたQRコードを読み取ります。",
    step3: "あとは、話しかけるだけ。",
    step3Desc:
      "プロジェクトとエージェントを選ぶか、GitHub Issue / PRから会話を始めましょう。",
    setupGuide: "セットアップガイドを読む",
    remoteNote:
      "外出先からはTailscale経由で安全に接続でき、SSHからBridgeをリモート管理することもできます。",
    download1: "出かけよう。",
    download2: "エージェントと一緒に。",
    downloadDesc: "無料で使える、オープンソースの開発ツール。",
    faqTitle: "気になること。",
    faq1Q: "エージェントはどこで動きますか？",
    faq1A:
      "自分のPC上で、セルフホストのBridge Serverを通じて動きます。CC PocketはそのPCに直接接続するクライアントです。AIへのリクエストは、お使いのCodex・Claude・Antigravityの設定に従って各プロバイダーで処理されます。",
    faq4Q: "3つのエージェントすべてが必要ですか？",
    faq4A:
      "いいえ。Codex、Claude、Antigravity（agy）のうちお使いのものだけで利用できます。設定画面から各エージェントをいつでもオン・オフできます。",
    faq2Q: "オフラインでは何ができますか？",
    faq2A:
      "送信メッセージをキューに保持し、再接続後や使用量制限のリセット後に自動で送信します。取りこぼした更新も復元されます。エージェントの作業継続にはPC側のオンライン接続が必要です。",
    faq3Q: "無料で使えますか？",
    faq3A:
      "はい。CC PocketはMITライセンスの無料アプリで、任意のアプリ内Supporter購入を用意しています。Codex・Claude・Antigravityの利用環境は別途必要です。",
    footerNote:
      "個人開発のオープンソースツールです。OpenAI・Anthropic・Googleの公式アプリではありません。",
    privacyLink: "プライバシーポリシー ↗",
    copy: "コマンドをコピー",
    copied: "クリップボードにコピーしました",
    copyFailed: "上のコマンドを選択してコピーしてください。",
    close: "スクリーンショットを閉じる",
    zoomChat: "チャット画面を拡大",
    zoomApprovals: "承認一覧を拡大",
    zoomRecent: "セッション一覧を拡大",
    zoomGit: "Git差分レビュー画面を拡大",
    zoomWorkspace: "ワークスペース画面を拡大",
    zoomNetwork: "送信待ちの画面を拡大",
    zoomImagegen: "画像生成の画面を拡大",
    zoomVideo: "動画プレイヤーを拡大",
    zoomAudio: "音声プレイヤーを拡大",
  },
  zh: {
    metaTitle: "CC Pocket — 把编程代理，装进口袋。",
    metaDescription:
      "用一个聊天界面操控 Codex、Claude 和 Antigravity。实时动态、一键审批、Git 差异审查、iPad 与 Mac 无缝续接。免费开源。",
    skip: "跳转到正文",
    navAgents: "代理",
    navWorkflow: "核心体验",
    navWorkspace: "工作区",
    navSetup: "快速开始",
    eyebrow: "自托管的编程代理移动端伴侣",
    hero1: "把编程代理，",
    hero2: "装进口袋。",
    heroDesc:
      "将 Codex、Claude 和 Antigravity 汇聚到为手机打造的聊天式工作空间。随时发起任务、审批操作、审查差异，并在 iPad 或 Mac 上无缝续接。",
    getApp: "获取 CC Pocket",
    quickStart: "快速开始",
    freeNote: "免费且开源（MIT）。通过自托管 Bridge Server 运行在你自己的电脑上。",
    artNote: "下一步，轻点即批。",
    platformLead: "手机优先，大屏同样顺手。",
    experimental: "实验版",
    agentsKicker: "01 — 三大代理，合而为一",
    agents1: "Codex、Claude、Antigravity。",
    agents2: "统一界面，随心切换。",
    agentsDesc:
      "在同一时间线中启动和恢复三大代理会话。按会话切换模型、思考级别与审批模式，随时查看 5 小时/每周套餐用量，并可在设置中按需开启或关闭代理。",
    agentCodexDesc:
      "续接 Codex CLI 与 Codex App 会话，支持 Plan 模式切换与 Codex Imagegen。",
    agentClaudeDesc:
      "支持实时活动栏与思考预览、会话回顾卡片，以及结构化问答表单。",
    agentAgyDesc:
      "基于 agy CLI，支持模型与思考级别选择、计划审阅、用量追踪与图片生成。",
    experienceKicker: "02 — 为移动而设计",
    experience1: "专业工具。",
    experience2: "轻松上手。",
    chatTitle: "就像平常聊天一样。",
    chatDesc:
      "每个任务都有专属房间。实时查看思考预览、命令执行与后台进度，并内置语音输入、手绘草图附件和 Markdown 补全。",
    approvalTitle: "下一步，一键审批。",
    approvalDesc:
      "在一个列表中查看所有等待处理的会话。无需回到电脑前，即可批准命令、文件编辑、MCP 请求或实施计划。",
    gitTitle: "审查差异，直接提交。",
    gitDesc:
      "查看语法高亮代码和图片差异、添加行评论交由 AI 审查，完成 stage、commit、push 或用 git worktree 隔离并行任务，并可直接从 GitHub Issues 与 PR 发起会话。",
    networkTitle: "信号不稳，输入不丢。",
    networkDesc:
      "离线或触及额度上限时消息自动排队，待恢复连接或额度重置后自动发送，遗漏的流式更新也会自动补齐。",
    desktopKicker: "03 — 同一份工作，随屏切换",
    desktop1: "离开书桌，",
    desktop2: "继续同一会话。",
    desktopDesc:
      "在 Mac 或 CLI 开始，在 iPhone、iPhone Duo 或 Android 上跟进。在 iPad 与桌面端，可并排打开会话列表、聊天、文件浏览器与 Git 差异。",
    macDownload: "下载 macOS 版",
    workspaceCaption: "三栏深色工作区，图为 iPad 版。",
    desktopExperimental: "Linux 和 Windows（实验版）",
    mediaKicker: "04 — 不止代码",
    media1: "生成。查看。",
    media2: "播放。",
    mediaDesc:
      "用 Codex Imagegen 或 Antigravity 生成图片，在聊天与图库中直接查看。视频和音频文件也无需离开应用即可播放。",
    imageCaption: "在聊天中查看生成的图片。",
    videoCaption: "预览、拖动进度、全屏播放。",
    audioCaption: "无需切换应用即可收听。",
    setupKicker: "05 — 快速开始",
    setupTitle: "一条命令，连接手机。",
    setupDesc:
      "电脑需安装 Node.js 22.19.0+，以及 Codex、Claude 或 Antigravity（agy）。",
    step1: "启动 Bridge。",
    step1Desc: "在运行代理的 Mac、Linux 或 Windows 电脑上执行此命令。",
    step2: "扫码连接。",
    step2Desc: "安装 CC Pocket，扫描终端中显示的二维码。",
    step3: "开始对话。",
    step3Desc: "选择项目和代理，或直接挑选 GitHub Issue / PR 发起任务。",
    setupGuide: "阅读设置指南",
    remoteNote: "外出时可通过 Tailscale 安全连接，也可通过 SSH 远程管理 Bridge。",
    download1: "出门吧。",
    download2: "带上你的代理。",
    downloadDesc: "免费使用，开放源代码。",
    faqTitle: "你可能想知道。",
    faq1Q: "代理在哪里运行？",
    faq1A:
      "通过自托管 Bridge Server 运行在你自己的电脑上。CC Pocket 直接连接到你的主机，AI 请求仍按你现有的 Codex、Claude 或 Antigravity 配置交由对应服务商处理。",
    faq4Q: "必须同时安装三个代理吗？",
    faq4A:
      "不需要。只用其中任意一个或任意组合即可，在设置中可以随时开启或关闭各个代理。",
    faq2Q: "离线时能做什么？",
    faq2A:
      "待发消息会自动排队，在恢复网络或额度重置后自动发送，并补齐错过的更新。代理持续工作需要电脑保持联网。",
    faq3Q: "免费吗？",
    faq3A:
      "是的。CC Pocket 基于 MIT 协议免费开源，提供可选的应用内 Supporter 内购支持。你需要自行准备 Codex、Claude 或 Antigravity 的使用权限。",
    footerNote: "独立开源工具，与 OpenAI、Anthropic 或 Google 无官方关联。",
    privacyLink: "隐私政策 ↗",
    copy: "复制命令",
    copied: "已复制到剪贴板",
    copyFailed: "请选择并复制上方命令。",
    close: "关闭截图",
    zoomChat: "放大聊天截图",
    zoomApprovals: "放大审批列表截图",
    zoomRecent: "放大会话列表截图",
    zoomGit: "放大 Git 差异审查截图",
    zoomWorkspace: "放大工作区截图",
    zoomNetwork: "放大待发送消息截图",
    zoomImagegen: "放大图片生成截图",
    zoomVideo: "放大视频播放器截图",
    zoomAudio: "放大音频播放器截图",
  },
  ko: {
    metaTitle: "CC Pocket — 에이전트를 주머니에.",
    metaDescription:
      "Codex, Claude, Antigravity를 하나의 채팅 UI로. 실시간 활동, 원탭 승인, Git diff 검토, iPad·Mac 연동까지. 무료 오픈 소스.",
    skip: "본문으로 이동",
    navAgents: "에이전트",
    navWorkflow: "워크플로",
    navWorkspace: "워크스페이스",
    navSetup: "시작하기",
    eyebrow: "코딩 에이전트를 위한 셀프 호스팅 모바일 클라이언트",
    hero1: "에이전트를,",
    hero2: "주머니에.",
    heroDesc:
      "Codex, Claude, Antigravity를 휴대폰에 맞춘 하나의 채팅 워크스페이스로. 작업 지시, 원탭 승인, diff 검토부터 iPad와 Mac에서의 이어가기까지 어디서든.",
    getApp: "CC Pocket 받기",
    quickStart: "시작하기",
    freeNote: "무료 오픈 소스(MIT). 내 컴퓨터의 Bridge Server에서 실행됩니다.",
    artNote: "다음 결정도 탭 한 번으로.",
    platformLead: "휴대폰이 중심. 모든 화면에서 자연스럽게.",
    experimental: "실험 버전",
    agentsKicker: "01 — 세 에이전트를 한곳에서",
    agents1: "Codex, Claude, Antigravity.",
    agents2: "하나의 UI로 제어.",
    agentsDesc:
      "세 에이전트의 세션을 하나의 타임라인에서 시작하고 이어가세요. 세션별 모델·사고 수준·승인 모드 전환, 5시간·주간 사용량 확인, 사용할 에이전트만 켜고 끄기까지 지원합니다.",
    agentCodexDesc:
      "Codex CLI 및 Codex App 세션 이어가기, Plan 모드 전환, Codex Imagegen 지원.",
    agentClaudeDesc:
      "실시간 활동 바와 사고 미리보기, 세션 요약 카드, 대화형 질문 양식 지원.",
    agentAgyDesc:
      "agy CLI 연동으로 모델·사고 수준 선택, 플랜 검토, 사용량 표시, 이미지 생성 지원.",
    experienceKicker: "02 — 이동하는 당신을 위해",
    experience1: "도구는 본격적으로.",
    experience2: "사용은 가볍게.",
    chatTitle: "익숙한 채팅처럼.",
    chatDesc:
      "작업마다 하나의 대화방. 실시간 사고 미리보기, 명령 실행, 백그라운드 진행 상황을 확인하고 음성 입력·스케치 첨부·Markdown 자동완성도 바로 사용하세요.",
    approvalTitle: "다음 결정도 탭 한 번으로.",
    approvalDesc:
      "여러 세션의 승인 대기를 한 목록에서 확인하세요. 자리로 돌아가지 않고도 명령 실행, 파일 편집, MCP 요청, 구현 플랜을 바로 승인할 수 있습니다.",
    gitTitle: "diff 검토부터 반영까지.",
    gitDesc:
      "구문 강조 코드·이미지 diff 확인과 줄 댓글 AI 검토, stage·commit·push·git worktree 분리까지 지원합니다. 열린 GitHub Issues와 PR에서 바로 세션을 시작할 수도 있습니다.",
    networkTitle: "신호가 끊겨도 작업은 그대로.",
    networkDesc:
      "오프라인 상태나 사용량 제한에 도달해도 프롬프트가 대기열에 보관되어 재연결·리셋 후 자동 전송되며, 놓친 스트리밍 업데이트도 복구됩니다.",
    desktopKicker: "03 — 같은 작업, 모든 화면",
    desktop1: "자리를 떠나도,",
    desktop2: "작업은 손안에.",
    desktopDesc:
      "Mac이나 CLI에서 시작하고 iPhone, iPhone Duo, Android에서 확인하세요. iPad와 데스크톱에서는 세션 목록, 채팅, 파일 탐색기, Git diff를 나란히 열어둘 수 있습니다.",
    macDownload: "macOS용 다운로드",
    workspaceCaption: "다크 모드의 3패널 워크스페이스(iPad 화면).",
    desktopExperimental: "Linux 및 Windows (실험 버전)",
    mediaKicker: "04 — 코드 그 너머",
    media1: "만들고. 보고.",
    media2: "재생하고.",
    mediaDesc:
      "Codex Imagegen과 Antigravity로 이미지를 생성해 채팅과 갤러리에서 확인하세요. 동영상과 오디오 결과물도 앱을 벗어나지 않고 바로 재생할 수 있습니다.",
    imageCaption: "생성한 이미지를 채팅에서 바로 확인.",
    videoCaption: "미리보기, 탐색, 전체 화면 재생까지.",
    audioCaption: "앱을 바꾸지 않고 바로 듣기.",
    setupKicker: "05 — 시작해 보세요",
    setupTitle: "명령어 하나로 바로 모바일 연결.",
    setupDesc:
      "컴퓨터에 Node.js 22.19.0 이상과 Codex, Claude 또는 Antigravity(agy)가 필요합니다.",
    step1: "Bridge 실행.",
    step1Desc: "에이전트가 설치된 Mac, Linux, Windows 컴퓨터에서 실행하세요.",
    step2: "QR로 연결.",
    step2Desc: "CC Pocket을 설치하고 터미널의 QR 코드를 스캔하세요.",
    step3: "대화를 시작하세요.",
    step3Desc:
      "프로젝트와 에이전트를 고르거나 GitHub Issue / PR을 선택해 바로 시작하세요.",
    setupGuide: "설정 가이드 읽기",
    remoteNote:
      "외출 중에는 Tailscale로 안전하게 연결하고 SSH로 Bridge를 원격 관리할 수 있습니다.",
    download1: "밖으로 나가세요.",
    download2: "에이전트와 함께.",
    downloadDesc: "무료로 사용하는 오픈 소스 개발 도구.",
    faqTitle: "몇 가지 알아둘 점.",
    faq1Q: "에이전트는 어디서 실행되나요?",
    faq1A:
      "셀프 호스팅 Bridge Server를 통해 내 컴퓨터에서 실행됩니다. CC Pocket은 내 컴퓨터에 직접 연결하는 클라이언트이며, AI 요청은 기존 Codex, Claude 또는 Antigravity 설정에 따라 각 제공업체가 처리합니다.",
    faq4Q: "세 에이전트를 모두 설치해야 하나요?",
    faq4A:
      "아니요. Codex, Claude, Antigravity(agy) 중 원하는 것만 골라 사용할 수 있으며 설정에서 언제든 켜고 끌 수 있습니다.",
    faq2Q: "오프라인에서 무엇을 할 수 있나요?",
    faq2A:
      "메시지가 전송 대기열에 보관되어 연결이 복원되거나 사용량 제한이 리셋되면 자동 전송되고 놓친 업데이트도 복구됩니다. 에이전트가 계속 작업하려면 컴퓨터가 온라인 상태여야 합니다.",
    faq3Q: "무료인가요?",
    faq3A:
      "네. CC Pocket은 MIT 라이선스의 무료 앱이며 선택적인 앱 내 Supporter 구매가 있습니다. Codex, Claude 또는 Antigravity 이용 권한은 별도로 필요합니다.",
    footerNote:
      "독립 오픈 소스 도구입니다. OpenAI, Anthropic 또는 Google의 공식 앱이 아닙니다.",
    privacyLink: "개인정보 처리방침 ↗",
    copy: "명령어 복사",
    copied: "클립보드에 복사되었습니다",
    copyFailed: "위 명령어를 선택하여 복사하세요.",
    close: "스크린샷 닫기",
    zoomChat: "대화 화면 확대",
    zoomApprovals: "승인 목록 확대",
    zoomRecent: "세션 목록 확대",
    zoomGit: "Git diff 검토 화면 확대",
    zoomWorkspace: "작업 공간 확대",
    zoomNetwork: "전송 대기 화면 확대",
    zoomImagegen: "이미지 생성 화면 확대",
    zoomVideo: "동영상 플레이어 확대",
    zoomAudio: "오디오 플레이어 확대",
  },
};

const languageSelect = document.getElementById("lang-selector");
let language = "en";
let copyTimer;

function renderLanguage(requested) {
  language = Object.hasOwn(translations, requested) ? requested : "en";
  const t = translations[language];
  document.documentElement.lang = language === "zh" ? "zh-CN" : language;
  document.title = t.metaTitle;
  for (const name of ["description", "og:description", "twitter:description"]) {
    document.querySelector(
      `meta[${name.startsWith("og:") ? "property" : "name"}="${name}"]`,
    ).content = t.metaDescription;
  }
  for (const name of ["og:title", "twitter:title"]) {
    document.querySelector(
      `meta[${name.startsWith("og:") ? "property" : "name"}="${name}"]`,
    ).content = t.metaTitle;
  }
  document.querySelectorAll("[data-i18n]").forEach((el) => {
    el.textContent = t[el.dataset.i18n] ?? english[el.dataset.i18n];
  });
  document.querySelectorAll("[data-i18n-label]").forEach((el) => {
    el.setAttribute(
      "aria-label",
      t[el.dataset.i18nLabel] ?? english[el.dataset.i18nLabel],
    );
  });
  languageSelect.value = language;
  document.getElementById("copy-status").textContent = "";
  try {
    localStorage.setItem("ccpocket_lang", language);
  } catch {
    /* Storage is optional. */
  }
}

let savedLanguage;
try {
  savedLanguage = localStorage.getItem("ccpocket_lang");
} catch {
  /* Private/restricted browsing. */
}
const queryLanguage = new URLSearchParams(location.search).get("lang");
const browserLanguage = navigator.language.toLowerCase().split("-")[0];
renderLanguage(queryLanguage || savedLanguage || browserLanguage);

languageSelect.addEventListener("change", () => {
  renderLanguage(languageSelect.value);
  const url = new URL(location.href);
  url.searchParams.set("lang", language);
  history.replaceState(null, "", url);
});

document.getElementById("copy-command").addEventListener("click", async () => {
  const code = document.getElementById("bridge-command");
  const status = document.getElementById("copy-status");
  clearTimeout(copyTimer);
  try {
    await navigator.clipboard.writeText(code.textContent);
    status.textContent = translations[language].copied;
    copyTimer = setTimeout(() => {
      status.textContent = "";
    }, 2500);
  } catch {
    const selection = window.getSelection();
    const range = document.createRange();
    range.selectNodeContents(code);
    selection.removeAllRanges();
    selection.addRange(range);
    status.textContent = translations[language].copyFailed;
  }
});

const dialog = document.getElementById("screenshot-dialog");
const zoomed = document.getElementById("zoomed-screenshot");
document.querySelectorAll("[data-zoom]").forEach((button) => {
  button.addEventListener("click", () => {
    const source = button.querySelector("img");
    zoomed.src = source.currentSrc || source.src;
    zoomed.alt = source.alt;
    dialog.showModal();
  });
});
document
  .getElementById("close-dialog")
  .addEventListener("click", () => dialog.close());
dialog.addEventListener("click", (event) => {
  if (event.target === dialog) dialog.close();
});
