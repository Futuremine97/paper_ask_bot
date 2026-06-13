// 대상 사이트(claude.ai / chatgpt.com)에서 이미지+프롬프트를 주입하고 전송합니다.
// 사이트 UI가 바뀌면 아래 SELECTORS 를 수정해야 할 수 있습니다.

(async () => {
  const store = await chrome.storage.local.get("pa_payload");
  const payload = store.pa_payload;
  if (!payload) return;
  await chrome.storage.local.remove("pa_payload");

  const { dataUrl, prompt, target } = payload;
  toast("Paper Assist: 이미지 첨부 중…");

  // --- 사이트별 셀렉터 (UI 변경 시 여기만 고치면 됩니다) ---
  const SELECTORS = {
    claude: {
      editor: 'div[contenteditable="true"].ProseMirror, div[contenteditable="true"]',
      fileInput: 'input[type="file"]',
      attachment: '[data-testid*="file"], img[alt], [class*="thumbnail"]',
      send: 'button[aria-label="Send message"], button[aria-label*="Send"], button[type="submit"]'
    },
    chatgpt: {
      editor: 'div#prompt-textarea[contenteditable="true"], #prompt-textarea, textarea#prompt-textarea',
      fileInput: 'input[type="file"]',
      attachment: 'img[alt], [class*="attachment"], button[aria-label*="Remove"]',
      send: 'button[data-testid="send-button"], button[aria-label*="Send"], button[aria-label*="보내기"]'
    }
  };
  const S = SELECTORS[target] || SELECTORS.claude;

  // --- 1) 에디터 대기 ---
  const editor = await waitFor(S.editor, 25000);
  if (!editor) {
    toast("Paper Assist: 입력창을 찾지 못했습니다. 페이지가 완전히 로드된 뒤 다시 시도하세요.", true);
    return;
  }
  editor.focus();

  // --- 2) 이미지 첨부 ---
  const file = dataURLtoFile(dataUrl, "capture.png");
  let attached = await attachViaFileInput(S.fileInput, file);
  if (!attached) attached = await attachViaPaste(editor, file);

  if (!attached) {
    toast("Paper Assist: 이미지 자동 첨부 실패. 이미지가 클립보드에 복사되었으니 ⌘V 로 붙여넣어 주세요.", true);
    // 클립보드 폴백
    try {
      const blob = await (await fetch(dataUrl)).blob();
      await navigator.clipboard.write([new ClipboardItem({ [blob.type]: blob })]);
    } catch (_) {}
  }

  // --- 3) 첨부 업로드 완료를 기다림(가능하면) ---
  await waitFor(S.attachment, 8000);
  await sleep(800);

  // --- 4) 프롬프트 입력 ---
  insertText(editor, prompt);
  await sleep(500);

  // --- 5) 전송 ---
  const sendBtn = await waitForEnabled(S.send, 8000);
  if (sendBtn) {
    sendBtn.click();
    toast("Paper Assist: 전송했습니다 ✓");
  } else {
    // 버튼을 못 찾으면 Enter 시도
    editor.focus();
    editor.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", code: "Enter", keyCode: 13, which: 13, bubbles: true }));
    toast("Paper Assist: 전송 버튼을 못 찾아 Enter 로 시도했습니다. 안 보내졌으면 직접 전송하세요.", true);
  }

  // ===== 헬퍼들 =====
  function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

  async function waitFor(sel, timeout) {
    const start = Date.now();
    while (Date.now() - start < timeout) {
      const el = queryAny(sel);
      if (el) return el;
      await sleep(300);
    }
    return null;
  }

  async function waitForEnabled(sel, timeout) {
    const start = Date.now();
    while (Date.now() - start < timeout) {
      const el = queryAny(sel);
      if (el && !el.disabled && el.getAttribute("aria-disabled") !== "true") return el;
      await sleep(300);
    }
    return queryAny(sel); // 마지막엔 그냥 반환
  }

  function queryAny(selList) {
    for (const sel of selList.split(",")) {
      const el = document.querySelector(sel.trim());
      if (el) return el;
    }
    return null;
  }

  function dataURLtoFile(durl, name) {
    const [head, b64] = durl.split(",");
    const mime = head.match(/:(.*?);/)[1];
    const bin = atob(b64);
    const arr = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
    return new File([arr], name, { type: mime });
  }

  async function attachViaFileInput(sel, f) {
    const inputs = [...document.querySelectorAll(sel.split(",")[0].trim())];
    for (const input of inputs) {
      try {
        const dt = new DataTransfer();
        dt.items.add(f);
        input.files = dt.files;
        input.dispatchEvent(new Event("input", { bubbles: true }));
        input.dispatchEvent(new Event("change", { bubbles: true }));
        await sleep(400);
        return true;
      } catch (_) {}
    }
    return false;
  }

  async function attachViaPaste(el, f) {
    try {
      const dt = new DataTransfer();
      dt.items.add(f);
      const ev = new ClipboardEvent("paste", { bubbles: true, cancelable: true });
      // 일부 브라우저는 생성자 clipboardData 를 무시하므로 강제로 정의
      Object.defineProperty(ev, "clipboardData", { value: dt });
      el.dispatchEvent(ev);
      await sleep(400);
      return true;
    } catch (_) {
      return false;
    }
  }

  function insertText(el, text) {
    el.focus();
    if (el.tagName === "TEXTAREA" || el.tagName === "INPUT") {
      const proto = el.tagName === "TEXTAREA" ? window.HTMLTextAreaElement : window.HTMLInputElement;
      const setter = Object.getOwnPropertyDescriptor(proto.prototype, "value").set;
      setter.call(el, text);
      el.dispatchEvent(new Event("input", { bubbles: true }));
    } else {
      // contenteditable
      try {
        document.execCommand("selectAll", false, null);
        document.execCommand("insertText", false, text);
      } catch (_) {
        el.textContent = text;
        el.dispatchEvent(new InputEvent("input", { bubbles: true }));
      }
    }
  }

  function toast(message, isErr) {
    let t = document.getElementById("__pa_toast");
    if (!t) {
      t = document.createElement("div");
      t.id = "__pa_toast";
      t.style.cssText =
        "position:fixed;z-index:2147483647;bottom:20px;right:20px;max-width:340px;" +
        "padding:12px 16px;border-radius:10px;font:13px -apple-system,system-ui,sans-serif;" +
        "color:#fff;box-shadow:0 6px 24px rgba(0,0,0,.3);transition:opacity .3s;";
      document.body.appendChild(t);
    }
    t.style.background = isErr ? "#c0392b" : "#0071e3";
    t.textContent = message;
    t.style.opacity = "1";
    clearTimeout(t._timer);
    t._timer = setTimeout(() => { t.style.opacity = "0"; }, 6000);
  }
})();
