const MODES = [
  { id: "summary",   name: "핵심 요약",   fragment: "전체 내용을 핵심 위주로 간결하게 요약" },
  { id: "detail",    name: "자세한 설명", fragment: "내용을 단계별로 자세히 풀어서 설명" },
  { id: "terms",     name: "용어 풀이",   fragment: "어려운 전문 용어를 쉽게 정의하고 설명" },
  { id: "math",      name: "수식 해석",   fragment: "수식의 각 기호 의미와 직관적 의미를 해석" },
  { id: "figure",    name: "그래프/표",   fragment: "그래프·표·그림이 나타내는 의미를 해석" },
  { id: "translate", name: "한국어 번역", fragment: "텍스트를 자연스러운 한국어로 번역(전문 용어는 원어 병기)" },
  { id: "code",      name: "코드 분석",   fragment: "코드의 동작을 단계별로 설명하고 버그·개선점을 지적" },
  { id: "critique",  name: "비판적 검토", fragment: "주장의 가정·한계·반론·약점을 비판적으로 검토" },
  { id: "eli5",      name: "쉽게 설명",   fragment: "비전공자도 이해할 수 있도록 쉬운 비유로 설명" },
  { id: "questions", name: "핵심 질문",   fragment: "내용을 더 깊이 이해하기 위한 핵심 질문을 제시" }
];

const $ = (id) => document.getElementById(id);
let target = "claude";
let selected = new Set(["summary", "terms"]);

function setStatus(msg, isErr = false) {
  const el = $("status");
  el.textContent = msg;
  el.className = "status" + (isErr ? " err" : "");
}

// 선택된 집중모드 + 추가 요청으로 프롬프트 합성
function composePrompt() {
  const chosen = MODES.filter((m) => selected.has(m.id));
  let p;
  if (chosen.length === 0) {
    p = "이 이미지를 분석해서 핵심 내용을 한국어로 명확하게 설명해 주세요.";
  } else {
    p = "이 이미지를 분석해 주세요. 특히 아래 항목에 집중해 주세요:\n";
    p += chosen.map((m) => "- " + m.fragment).join("\n");
    p += "\n모두 한국어로 답변해 주세요.";
  }
  const extra = $("extra").value.trim();
  if (extra) p += "\n\n추가 요청: " + extra;
  $("prompt").value = p;
  save();
}

// 집중모드 칩 렌더링
const modesEl = $("modes");
MODES.forEach((m) => {
  const b = document.createElement("button");
  b.textContent = m.name;
  b.dataset.id = m.id;
  b.addEventListener("click", () => {
    if (selected.has(m.id)) selected.delete(m.id);
    else selected.add(m.id);
    b.classList.toggle("active", selected.has(m.id));
    composePrompt();
  });
  modesEl.appendChild(b);
});

function refreshChips() {
  [...modesEl.children].forEach((c) =>
    c.classList.toggle("active", selected.has(c.dataset.id))
  );
}

// 서비스 선택
$("targetSeg").addEventListener("click", (e) => {
  const btn = e.target.closest("button[data-target]");
  if (!btn) return;
  target = btn.dataset.target;
  [...$("targetSeg").children].forEach((c) => c.classList.toggle("active", c === btn));
  save();
});

$("extra").addEventListener("input", composePrompt);
$("prompt").addEventListener("input", save);

function save() {
  chrome.storage.local.set({
    pa_prompt: $("prompt").value,
    pa_target: target,
    pa_modes: [...selected],
    pa_extra: $("extra").value
  });
}

// 저장된 값 복원
chrome.storage.local.get(["pa_target", "pa_modes", "pa_extra"], (r) => {
  if (r.pa_target) {
    target = r.pa_target;
    [...$("targetSeg").children].forEach((c) =>
      c.classList.toggle("active", c.dataset.target === target)
    );
  }
  if (Array.isArray(r.pa_modes)) selected = new Set(r.pa_modes);
  if (typeof r.pa_extra === "string") $("extra").value = r.pa_extra;
  refreshChips();
  composePrompt();
});

// 실행
$("go").addEventListener("click", async () => {
  const prompt = $("prompt").value.trim();
  if (!prompt) {
    setStatus("집중모드를 선택하거나 프롬프트를 입력하세요.", true);
    return;
  }
  $("go").disabled = true;
  setStatus("현재 탭 캡처 중…");
  try {
    const res = await chrome.runtime.sendMessage({ type: "CAPTURE_AND_SEND", target, prompt });
    if (res && res.ok) {
      setStatus("완료! 열린 탭에서 분석이 진행됩니다.");
      setTimeout(() => window.close(), 800);
    } else {
      setStatus("오류: " + (res?.error || "알 수 없는 오류"), true);
      $("go").disabled = false;
    }
  } catch (e) {
    setStatus("오류: " + String(e), true);
    $("go").disabled = false;
  }
});
