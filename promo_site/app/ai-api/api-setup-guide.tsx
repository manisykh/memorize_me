"use client";

import { useRef, useState } from "react";
import type { CSSProperties, KeyboardEvent as ReactKeyboardEvent } from "react";

const guideSteps = [
  {
    tab: "시작 위치",
    marker: "시작",
    eyebrow: "API 등록 화면 열기",
    title: "설정에서 AI 연결을 시작합니다",
    body: "설정의 ‘AI 모델과 API’를 열고 무료 AI 추가 또는 보유 키 추가를 누르세요.",
    image: "/media/api-guide/setup-start-20261125.jpg",
    imageAlt: "설정 화면에서 AI 모델과 API 메뉴를 연 앱 화면",
  },
  {
    tab: "제공업체",
    marker: "1",
    eyebrow: "제공업체 선택",
    title: "사용할 AI 제공업체를 고릅니다",
    body: "처음이라면 앱에 표시된 초보 추천과 무료 플랜을 확인하세요. 이미 키가 있다면 해당 키의 제공업체를 선택합니다.",
    image: "/media/api-guide/setup-provider-20261125.jpg",
    imageAlt: "무료 API 제공업체를 선택하는 첫 번째 단계",
  },
  {
    tab: "키 연결",
    marker: "2",
    eyebrow: "API 키 연결",
    title: "준비한 API 키를 연결합니다",
    body: "사용할 모델을 확인하고 발급받은 API 키를 입력한 뒤 안전하게 저장하세요.",
    image: "/media/api-guide/setup-key-20261125.jpg",
    imageAlt: "공식 홈페이지에서 준비한 API 키를 입력하는 두 번째 단계",
  },
  {
    tab: "연결 확인",
    marker: "3",
    eyebrow: "연결 테스트",
    title: "짧은 테스트로 실제 작동을 확인합니다",
    body: "모델과 키가 정상일 때 등록을 완료합니다. 실패하면 제공업체·모델·키를 수정한 뒤 다시 테스트할 수 있습니다.",
    image: "/media/api-guide/setup-success-20261125.jpg",
    imageAlt: "AI 연결 테스트에 성공한 앱 화면",
  },
  {
    tab: "등록 완료",
    marker: "완료",
    eyebrow: "등록된 AI 관리",
    title: "연결한 AI가 관리 카드로 나타납니다",
    body: "가장 위 카드가 주 모델이 됩니다. 자동 대체를 켜면 오류가 발생할 때 아래에 둔 모델을 순서대로 시도합니다.",
    image: "/media/api-guide/setup-registered-20261125.jpg",
    imageAlt: "등록한 AI 카드와 자동 대체 순서를 관리하는 화면",
  },
] as const;

export function ApiSetupGuide() {
  const [activeStep, setActiveStep] = useState(0);
  const tabListRef = useRef<HTMLDivElement>(null);
  const touchStartX = useRef<number | null>(null);
  const selected = guideSteps[activeStep];
  // Settings screens include the app's bottom tab bar; setup screens only
  // include Android's gesture bar. Keep every other part of the app visible.
  const cropTop = 74;
  const cropBottom = activeStep === 0 || activeStep === 4 ? 244 : 50;
  const visibleHeight = 2340 - cropTop - cropBottom;
  const screenshotStyle = {
    aspectRatio: `1080 / ${visibleHeight}`,
    "--setup-image-height": `${(2340 / visibleHeight) * 100}%`,
    "--setup-image-top": `${(-cropTop / visibleHeight) * 100}%`,
  } as CSSProperties;

  const selectStep = (index: number, focusTab = false) => {
    const next = (index + guideSteps.length) % guideSteps.length;
    setActiveStep(next);
    requestAnimationFrame(() => {
      const tab = tabListRef.current?.querySelectorAll<HTMLButtonElement>("[role='tab']")[next];
      tab?.scrollIntoView({ behavior: "smooth", block: "nearest", inline: "center" });
      if (focusTab) tab?.focus();
    });
  };

  const handleKeyDown = (event: ReactKeyboardEvent<HTMLDivElement>) => {
    if (event.key === "ArrowRight" || event.key === "ArrowDown") {
      event.preventDefault();
      selectStep(activeStep + 1, true);
    } else if (event.key === "ArrowLeft" || event.key === "ArrowUp") {
      event.preventDefault();
      selectStep(activeStep - 1, true);
    } else if (event.key === "Home") {
      event.preventDefault();
      selectStep(0, true);
    } else if (event.key === "End") {
      event.preventDefault();
      selectStep(guideSteps.length - 1, true);
    }
  };

  const handleSwipeStart = (clientX: number) => {
    touchStartX.current = clientX;
  };

  const handleSwipeEnd = (clientX: number) => {
    const startX = touchStartX.current;
    touchStartX.current = null;
    if (startX === null) return;
    const distance = clientX - startX;
    if (Math.abs(distance) >= 48) selectStep(activeStep + (distance < 0 ? 1 : -1));
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
            onClick={() => selectStep(index)}
          >
            <span>{step.marker}</span>
            <strong>{step.tab}</strong>
          </button>
        ))}
      </div>

      <div
        id="api-setup-panel"
        className="api-setup-panel"
        role="tabpanel"
        aria-roledescription="carousel"
        aria-label={`${selected.tab}, ${activeStep + 1}/${guideSteps.length}`}
        aria-labelledby={`api-setup-tab-${activeStep}`}
        onTouchStart={(event) => handleSwipeStart(event.changedTouches[0]?.clientX ?? 0)}
        onTouchEnd={(event) => handleSwipeEnd(event.changedTouches[0]?.clientX ?? 0)}
      >
        <div className="api-setup-copy" key={`copy-${activeStep}`}>
          <p>{selected.eyebrow}</p>
          <h3>{selected.title}</h3>
          <span>{selected.body}</span>
        </div>

        <div className="api-setup-carousel">
          <figure className="api-setup-visual" key={`visual-${activeStep}`}>
            <div>
              <div className="api-setup-screenshot" style={screenshotStyle}>
                <img src={selected.image} alt={selected.imageAlt} draggable="false" width="1080" height="2340" />
              </div>
            </div>
            <figcaption>{selected.marker} · {selected.eyebrow}</figcaption>
          </figure>
          <div className="api-setup-controls">
            <button type="button" onClick={() => selectStep(activeStep - 1)} aria-label="이전 연결 단계">←</button>
            <div className="api-setup-pagination" aria-label={`${activeStep + 1}/${guideSteps.length} 단계`}>
              {guideSteps.map((step, index) => (
                <button key={step.tab} type="button" aria-label={`${step.tab} 보기`} aria-current={activeStep === index ? "step" : undefined} onClick={() => selectStep(index)}><span /></button>
              ))}
            </div>
            <button type="button" onClick={() => selectStep(activeStep + 1)} aria-label="다음 연결 단계">→</button>
          </div>
        </div>
      </div>
    </div>
  );
}
