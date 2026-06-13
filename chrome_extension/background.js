// 서비스워커: 현재 탭 캡처 → 대상 사이트 열기 → 콘텐츠 스크립트 주입

const TARGET_URL = {
  claude: "https://claude.ai/new",
  chatgpt: "https://chatgpt.com/"
};

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type === "CAPTURE_AND_SEND") {
    handle(msg)
      .then((r) => sendResponse(r))
      .catch((e) => sendResponse({ ok: false, error: String(e && e.message || e) }));
    return true; // 비동기 응답
  }
});

async function handle({ target, prompt }) {
  // 1) 현재 활성 탭 캡처
  const [activeTab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!activeTab) throw new Error("활성 탭을 찾을 수 없습니다.");

  const dataUrl = await chrome.tabs.captureVisibleTab(activeTab.windowId, { format: "png" });
  if (!dataUrl) throw new Error("탭 캡처에 실패했습니다.");

  // 2) 페이로드 저장 (콘텐츠 스크립트가 읽음)
  await chrome.storage.local.set({ pa_payload: { dataUrl, prompt, target, ts: Date.now() } });

  // 3) 대상 사이트 새 탭으로 열기
  const url = TARGET_URL[target] || TARGET_URL.claude;
  const newTab = await chrome.tabs.create({ url, active: true });

  // 4) 로드 완료 대기
  await waitForComplete(newTab.id, 25000);
  // SPA 렌더링 여유
  await sleep(1200);

  // 5) 콘텐츠 스크립트 주입
  await chrome.scripting.executeScript({
    target: { tabId: newTab.id },
    files: ["content.js"]
  });

  return { ok: true };
}

function waitForComplete(tabId, timeout) {
  return new Promise((resolve) => {
    let done = false;
    const finish = () => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      chrome.tabs.onUpdated.removeListener(listener);
      resolve();
    };
    const timer = setTimeout(finish, timeout);
    function listener(id, info) {
      if (id === tabId && info.status === "complete") finish();
    }
    chrome.tabs.onUpdated.addListener(listener);
    // 이미 완료된 경우 대비
    chrome.tabs.get(tabId, (t) => {
      if (chrome.runtime.lastError) return;
      if (t && t.status === "complete") finish();
    });
  });
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}
