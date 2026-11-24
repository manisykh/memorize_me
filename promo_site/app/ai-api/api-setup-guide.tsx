"use client";

import { useRef, useState } from "react";
import type { KeyboardEvent as ReactKeyboardEvent } from "react";

const guideSteps = [
  {
    tab: "시작 위치",
    marker: "시작",
    eyebrow: "API 등록 화면 열기",
    title: "설정에서 AI 모델과 API를 엽니다",
    body: "앱 하단의 설정을 누르고 ‘AI 모델과 API’를 펼친 뒤, 무료 AI 추가 또는 보유 키 추가를 선택하세요.",
    path: ["설정", "AI 모델과 API", "무료 AI 추가 · 보유 키 추가"],
    image: "/media/latest/ai-settings.png",
    imageAlt: "설정 화면에서 AI 모델과 API 메뉴를 연 앱 화면",
  },
  {
    tab: "제공업체",
    marker: "1",
    eyebrow: "제공업체 선택",
    title: "사용할 AI 제공업체를 고릅니다",
    body: "처음이라면 앱에 표시된 초보 추천과 무료 플랜을 확인하세요. 이미 키가 있다면 해당 키의 제공업체를 선택합니다.",
    image: "/media/latest/ai-provider-step1.png",
    imageAlt: "무료 API 제공업체를 선택하는 첫 번째 단계",
  },
  {
    tab: "키 연결",
    marker: "2",
    eyebrow: "API 키 연결",
    title: "발급 안내를 따라 키를 붙여넣습니다",
    body: "앱에서 발급 주소와 순서를 확인한 뒤 복사한 API 키를 입력하세요. API 키는 계정 비밀번호와 다릅니다.",
    image: "/media/latest/ai-provider-step2.png",
    imageAlt: "발급 안내를 확인하고 API 키를 입력하는 두 번째 단계",
  },
  {
    tab: "연결 확인",
    marker: "3",
    eyebrow: "연결 테스트",
    title: "짧은 테스트로 실제 작동을 확인합니다",
    body: "모델과 키가 정상일 때 등록을 완료합니다. 실패하면 제공업체·모델·키를 수정한 뒤 다시 테스트할 수 있습니다.",
    image: "/media/manual/ai-connect-success.jpg",
    imageAlt: "AI 연결 테스트에 성공한 앱 화면",
  },
  {
    tab: "등록 완료",
    marker: "완료",
    eyebrow: "등록된 AI 관리",
    title: "연결한 AI가 관리 카드로 나타납니다",
    body: "가장 위 카드가 주 모델이 됩니다. 자동 대체를 켜면 오류가 발생할 때 아래에 둔 모델을 순서대로 시도합니다.",
    image: "/media/manual/ai-fallback.jpg",
    imageAlt: "등록한 AI 카드와 자동 대체 순서를 관리하는 화면",
  },
] as const;

export function ApiSetupGuide() {
  const [activeStep, setActiveStep] = useState(0);
  const tabListRef = useRef<HTMLDivElement>(null);
  const selected = guideSteps[activeStep];

  const selectStep = (index: number) => {
    const next = (index + guideSteps.length) % guideSteps.length;
    setActiveStep(next);
    requestAnimationFrame(() => {
      tabListRef.current?.querySelectorAll<HTMLButtonElement>("[role='tab']")[next]?.focus();
    });
  };

  const handleKeyDown = (event: ReactKeyboardEvent<HTMLDivElement>) => {
    if (event.key === "ArrowRight" || event.key === "ArrowDown") {
      event.preventDefault();
      selectStep(activeStep + 1);
    } else if (event.key === "ArrowLeft" || event.key === "ArrowUp") {
      event.preventDefault();
      selectStep(activeStep - 1);
    } else if (event.key === "Home") {
      event.preventDefault();
      selectStep(0);
    } else if (event.key === "End") {
      event.preventDefault();
      selectStep(guideSteps.length - 1);
    }
  };

  return (
    <div className="api-setup-explorer">
      <div ref={tabListRef} className="api-setup-tabs" role="tablist" aria-label="AI API 연결 단계" onKeyDown={handleKeyDown}>
        {guideSteps.map((step, index) => (
          <button
            id={`api-setup-tab-${index}`}
            key={step.tab}
            type="button"
            role="tab"
            aria-selected={activeStep === index}
            aria-controls="api-setup-panel"
            tabIndex={activeStep === index ? 0 : -1}
            onClick={() => setActiveStep(index)}
          >
            <span>{step.marker}</span>
            <strong>{step.tab}</strong>
          </button>
        ))}
      </div>

      <div id="api-setup-panel" className="api-setup-panel" role="tabpanel" aria-labelledby={`api-setup-tab-${activeStep}`}>
        <div className="api-setup-copy" key={`copy-${activeStep}`}>
          <p>{selected.eyebrow}</p>
          <h3>{selected.title}</h3>
          <span>{selected.body}</span>
          {"path" in selected ? (
            <ol className="api-entry-path" aria-label="API 등록 화면 진입 경로">
              {selected.path.map((item) => <li key={item}>{item}</li>)}
            </ol>
          ) : null}
          <div className="api-setup-pagination" aria-label={`${activeStep + 1}/${guideSteps.length} 단계`}>
            {guideSteps.map((step, index) => (
              <button key={step.tab} type="button" aria-label={`${step.tab} 보기`} aria-current={activeStep === index ? "step" : undefined} onClick={() => setActiveStep(index)}><span /></button>
            ))}
          </div>
        </div>

        <figure className="api-setup-visual" key={`visual-${activeStep}`}>
          <div><img src={selected.image} alt={selected.imageAlt} /></div>
          <figcaption>{selected.marker} · {selected.eyebrow}</figcaption>
        </figure>
      </div>
    </div>
  );
}
