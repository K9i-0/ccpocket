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
    "Codex and Claude Code, built for your phone. Chat, approve, review, and pick up the same work on your Mac. Free and open source.",
  copy: "Copy command",
  copied: "Copied",
  copyFailed: "Select and copy the command above.",
  close: "Close screenshot",
  zoomChat: "Enlarge chat screenshot",
  zoomSessions: "Enlarge session list screenshot",
  zoomWorkspace: "Enlarge workspace screenshot",
});
const translations = {
  en: english,
  ja: {
    metaTitle: "CC Pocket — エージェントを、ポケットに。",
    metaDescription:
      "CodexとClaude Codeを、スマホのためのUIで。チャット、承認、差分レビュー。Macと同じセッションを、外出先でも。無料・オープンソース。",
    skip: "本文へ移動",
    navExperience: "できること",
    navSetup: "はじめ方",
    eyebrow: "デスクから、少し自由に。",
    hero1: "エージェントを、",
    hero2: "ポケットに。",
    heroDesc:
      "CodexとClaude Codeを、スマホのためのUIで。思いついたら話しかけて、どこからでも開発の続きを。",
    getApp: "CC Pocketを入手",
    quickStart: "はじめ方",
    freeNote: "無料。オープンソース。いつもの開発環境で。",
    artNote: "次の一手は、ワンタップで。",
    platformLead: "スマホが主役。大きな画面でも、心地よく。",
    experimental: "試験提供",
    experienceKicker: "01 — 移動するあなたのために",
    experience1: "できることは、本格的。",
    experience2: "使い心地は、軽やか。",
    chatTitle: "いつものチャット感覚で。",
    chatDesc:
      "タスクごとに、ひとつの部屋。依頼も、質問への回答も、変更の承認も。会話の流れで完結します。",
    demoPrompt: "チェックアウト画面を、すっきり整えて。",
    demoReply: "変更できました。確認しますか？",
    demoApproval: "レビューの準備ができました",
    illustration: "会話のイメージ",
    networkTitle: "電波が途切れても、その先へ。",
    networkDesc:
      "圏外で書いたメッセージは送信待ちに。再接続すると自動で送信し、見逃した更新も取り戻します。",
    queued: "送信待ち",
    delivered: "再接続して、送信完了。",
    desktopKicker: "02 — 同じ作業を、どの画面でも",
    desktop1: "Macを離れても、",
    desktop2: "続きは、その手の中に。",
    desktopDesc:
      "Macで始めて、スマホで確認。同じセッションに接続すれば、会話も変更内容も、そのまま続けられます。",
    macDownload: "macOS版をダウンロード",
    workspaceCaption: "大きな画面では、チャットも差分も一望。画面はiPad版。",
    desktopExperimental: "Linux・Windows（試験提供）",
    mediaKicker: "03 — コードの、その先まで",
    media1: "つくる。見る。",
    media2: "再生する。",
    mediaDesc:
      "CodexのImagegenで画像を生成し、チャットで確認。動画や音声ファイルも、アプリを離れず再生できます。",
    mediaIllustration: "メディアプレビューのイメージ",
    setupKicker: "04 — はじめよう",
    setupTitle: "コマンドひとつで接続。",
    setupDesc:
      "PCにNode.js 20.18.1以上と、CodexまたはClaude Codeをご用意ください。",
    step1: "Bridgeを起動。",
    step1Desc: "エージェントを使うPCで実行します。",
    step2: "QRをスキャン。",
    step2Desc: "CC Pocketを入れて、ターミナルのQRコードを読み取ります。",
    step3: "あとは、話しかけるだけ。",
    step3Desc: "プロジェクトとエージェントを選んで、会話を始めましょう。",
    setupGuide: "セットアップガイド",
    remoteNote: "外出先からは、Tailscale経由で自分のPCに接続できます。",
    download1: "出かけよう。",
    download2: "エージェントと一緒に。",
    downloadDesc: "無料で使える、オープンソースの開発ツール。",
    faqTitle: "気になること。",
    faq1Q: "エージェントはどこで動きますか？",
    faq1A:
      "自分のPC上で、Bridge Serverを通じて動きます。CC PocketはそのPCに接続するクライアントです。AIへのリクエストは、お使いのCodexやClaude Codeの設定に従って各プロバイダーで処理されます。",
    faq2Q: "オフラインで、何ができますか？",
    faq2A:
      "メッセージを送信待ちにできます。再接続すると自動で送信され、受け取れなかった更新も復元されます。エージェントの作業を継続するには、PC側の接続が必要です。",
    faq3Q: "無料で使えますか？",
    faq3A:
      "はい。CC Pocketは無料で使えます。任意のアプリ内サポーター購入も用意しています。CodexやClaude Codeの利用環境は別途必要です。",
    footerNote:
      "個人開発のツールです。OpenAI・Anthropicの公式アプリではありません。",
    copy: "コマンドをコピー",
    copied: "コピーしました",
    copyFailed: "上のコマンドを選択してコピーしてください。",
    close: "スクリーンショットを閉じる",
    zoomChat: "チャット画面を拡大",
    zoomSessions: "セッション一覧を拡大",
    zoomWorkspace: "ワークスペース画面を拡大",
  },
  zh: {
    metaTitle: "CC Pocket — 把编程智能体，装进口袋。",
    metaDescription:
      "在手机上使用 Codex 和 Claude Code。聊天、审批、查看差异，与 Mac 接续同一会话。免费开源。",
    skip: "跳转到正文",
    navExperience: "使用体验",
    navSetup: "快速开始",
    eyebrow: "离开书桌，也能继续。",
    hero1: "编程智能体，",
    hero2: "装进口袋。",
    heroDesc:
      "Codex 和 Claude Code，配上为手机设计的界面。随时发起对话，随地继续开发。",
    getApp: "获取 CC Pocket",
    quickStart: "快速开始",
    freeNote: "免费。开源。使用你自己的电脑。",
    artNote: "下一步，轻点即可。",
    platformLead: "手机优先，大屏同样顺手。",
    experimental: "实验版",
    experienceKicker: "01 — 为移动而设计",
    experience1: "专业工具。",
    experience2: "轻松上手。",
    chatTitle: "就像平常聊天一样。",
    chatDesc:
      "每个任务一个聊天室。发送需求、回答问题、批准修改，在对话中完成。",
    demoPrompt: "把结账页面整理得更简洁。",
    demoReply: "修改已完成。要看看吗？",
    demoApproval: "等待你的审阅",
    illustration: "对话示意",
    networkTitle: "信号不稳，进度不丢。",
    networkDesc: "离线消息暂存队列，重新连接后自动发送。错过的更新也会恢复。",
    queued: "等待发送",
    delivered: "已重连，已发送。",
    desktopKicker: "02 — 同一份工作，随屏切换",
    desktop1: "离开 Mac，",
    desktop2: "在手机上接着做。",
    desktopDesc: "在 Mac 上开始，在手机上查看。连接同一会话，对话和修改都在。",
    macDownload: "下载 macOS 版",
    workspaceCaption: "大屏工作区：会话、聊天和差异并排显示。图为 iPad 版。",
    desktopExperimental: "Linux 和 Windows（实验版）",
    mediaKicker: "03 — 不止代码",
    media1: "生成。查看。",
    media2: "播放。",
    mediaDesc:
      "用 Codex Imagegen 生成图片，在聊天中查看结果。视频和音频文件也能直接在应用中播放。",
    mediaIllustration: "媒体预览示意",
    setupKicker: "04 — 开始使用",
    setupTitle: "一条命令，连接手机。",
    setupDesc: "电脑需安装 Node.js 20.18.1+，以及 Codex 或 Claude Code。",
    step1: "启动 Bridge。",
    step1Desc: "在运行智能体的电脑上执行此命令。",
    step2: "扫码连接。",
    step2Desc: "安装 CC Pocket，扫描终端中的二维码。",
    step3: "开始对话。",
    step3Desc: "选择项目和智能体，开始工作。",
    setupGuide: "阅读设置指南",
    remoteNote: "外出时，可通过 Tailscale 连接自己的电脑。",
    download1: "出门吧。",
    download2: "带上你的智能体。",
    downloadDesc: "免费使用，开放源代码。",
    faqTitle: "你可能想知道。",
    faq1Q: "智能体在哪里运行？",
    faq1A:
      "通过自托管的 Bridge Server 在你的电脑上运行。CC Pocket 是连接客户端。AI 请求仍按现有 Codex 或 Claude Code 配置交由各自的服务商处理。",
    faq2Q: "离线时能做什么？",
    faq2A:
      "消息会加入发送队列。恢复连接后自动发送，并补齐错过的更新。智能体持续工作需要电脑保持联网。",
    faq3Q: "免费吗？",
    faq3A:
      "是的。CC Pocket 免费使用，也提供可选的应用内支持者购买。你需要自行准备 Codex 或 Claude Code 的使用权限。",
    footerNote: "独立开发工具，与 OpenAI 或 Anthropic 无官方关联。",
    copy: "复制命令",
    copied: "已复制",
    copyFailed: "请选择并复制上方命令。",
    close: "关闭截图",
    zoomChat: "放大聊天截图",
    zoomSessions: "放大会话截图",
    zoomWorkspace: "放大工作区截图",
  },
  ko: {
    metaTitle: "CC Pocket — 에이전트를 주머니에.",
    metaDescription:
      "휴대폰에서 Codex와 Claude Code를 사용하세요. 대화, 승인, 변경 검토를 하고 Mac에서 같은 세션을 이어 가세요. 무료 오픈 소스.",
    skip: "본문으로 이동",
    navExperience: "기능",
    navSetup: "시작하기",
    eyebrow: "책상에서 조금 더 자유롭게.",
    hero1: "에이전트를,",
    hero2: "주머니에.",
    heroDesc:
      "Codex와 Claude Code를 휴대폰에 맞춘 UI로. 생각나면 말을 걸고, 어디서든 개발을 이어 가세요.",
    getApp: "CC Pocket 받기",
    quickStart: "시작하기",
    freeNote: "무료. 오픈 소스. 내 컴퓨터에서.",
    artNote: "다음 작업은 탭 한 번으로.",
    platformLead: "휴대폰이 중심. 큰 화면에서도 편하게.",
    experimental: "실험 버전",
    experienceKicker: "01 — 이동하는 당신을 위해",
    experience1: "도구는 본격적으로.",
    experience2: "사용은 가볍게.",
    chatTitle: "익숙한 채팅처럼.",
    chatDesc:
      "작업마다 하나의 대화방. 요청, 질문에 대한 답변, 변경 승인까지 대화 안에서 처리하세요.",
    demoPrompt: "결제 화면을 더 깔끔하게 정리해 줘.",
    demoReply: "변경이 준비됐어요. 확인할까요?",
    demoApproval: "검토할 준비가 됐어요",
    illustration: "대화 예시",
    networkTitle: "신호가 끊겨도, 이어서.",
    networkDesc:
      "오프라인 메시지는 대기열에 저장됩니다. 다시 연결되면 자동으로 전송되고 놓친 업데이트도 복원됩니다.",
    queued: "전송 대기",
    delivered: "재연결. 전송 완료.",
    desktopKicker: "02 — 같은 작업, 다른 화면",
    desktop1: "Mac을 떠나도,",
    desktop2: "작업은 손안에.",
    desktopDesc:
      "Mac에서 시작하고 휴대폰에서 확인하세요. 같은 세션에 연결하면 대화와 변경 내용이 그대로 이어집니다.",
    macDownload: "macOS용 다운로드",
    workspaceCaption:
      "대화와 변경 내용을 한눈에 보는 큰 화면 작업 공간. iPad 화면입니다.",
    desktopExperimental: "Linux 및 Windows (실험 버전)",
    mediaKicker: "03 — 코드 그 너머",
    media1: "만들고. 보고.",
    media2: "재생하고.",
    mediaDesc:
      "Codex Imagegen으로 이미지를 만들고 대화에서 확인하세요. 동영상과 오디오 파일도 앱 안에서 재생할 수 있습니다.",
    mediaIllustration: "미디어 미리보기 예시",
    setupKicker: "04 — 시작해 보세요",
    setupTitle: "명령어 하나로 휴대폰과 연결.",
    setupDesc:
      "컴퓨터에 Node.js 20.18.1 이상과 Codex 또는 Claude Code가 필요합니다.",
    step1: "Bridge 실행.",
    step1Desc: "에이전트가 설치된 컴퓨터에서 실행하세요.",
    step2: "QR로 연결.",
    step2Desc: "CC Pocket을 설치하고 터미널의 QR 코드를 스캔하세요.",
    step3: "대화를 시작하세요.",
    step3Desc: "프로젝트와 에이전트를 선택하면 준비 끝.",
    setupGuide: "설정 가이드 읽기",
    remoteNote: "외출 중에는 Tailscale로 내 컴퓨터에 연결하세요.",
    download1: "밖으로 나가세요.",
    download2: "에이전트와 함께.",
    downloadDesc: "무료로 사용하는 오픈 소스 개발 도구.",
    faqTitle: "몇 가지 알아둘 점.",
    faq1Q: "에이전트는 어디서 실행되나요?",
    faq1A:
      "자체 호스팅 Bridge Server를 통해 내 컴퓨터에서 실행됩니다. CC Pocket은 연결 클라이언트입니다. AI 요청은 기존 Codex 또는 Claude Code 설정에 따라 각 제공업체가 처리합니다.",
    faq2Q: "오프라인에서 무엇을 할 수 있나요?",
    faq2A:
      "메시지가 전송 대기열에 저장됩니다. 연결이 복원되면 자동 전송되고 놓친 업데이트도 복구됩니다. 에이전트가 계속 작업하려면 컴퓨터가 온라인 상태여야 합니다.",
    faq3Q: "무료인가요?",
    faq3A:
      "네. CC Pocket은 무료이며 선택적인 앱 내 서포터 구매가 있습니다. Codex 또는 Claude Code 이용 권한은 별도로 필요합니다.",
    footerNote:
      "독립 개발 도구입니다. OpenAI 또는 Anthropic의 공식 앱이 아닙니다.",
    copy: "명령어 복사",
    copied: "복사됨",
    copyFailed: "위 명령어를 선택하여 복사하세요.",
    close: "스크린샷 닫기",
    zoomChat: "대화 화면 확대",
    zoomSessions: "세션 목록 확대",
    zoomWorkspace: "작업 공간 확대",
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
