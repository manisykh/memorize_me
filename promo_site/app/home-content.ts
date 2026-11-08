export type JourneyKey = "import" | "learn" | "review";

export type JourneyStep = {
  key: JourneyKey;
  label: string;
  title: string;
  description: string;
  points: string[];
  image: string;
  imageAlt: string;
  guideHref: string;
};

export const journeySteps: JourneyStep[] = [
  {
    key: "import",
    label: "단어장 준비",
    title: "정리한 단어장을 그대로 가져오세요",
    description: "단어와 뜻이 열로 정리된 Google Sheets·CSV·XLSX를 선택합니다. 앱에서 새 단어장을 직접 만들 수도 있습니다.",
    points: ["단어·뜻 열 확인", "가져올 파일과 시트 선택", "현재 학습 단어장 지정"],
    image: "/media/feature/sheet-selection-current.svg",
    imageAlt: "가져올 시트를 선택하는 Memorize Me 화면",
    guideHref: "/manual#wordbook",
  },
  {
    key: "learn",
    label: "첫 학습",
    title: "원하는 방식으로 첫 학습을 시작하세요",
    description: "단어장을 선택하고 플래시카드·객관식·스펠링 중 원하는 방식으로 오늘 범위를 학습합니다.",
    points: ["학습 단어장 선택", "학습 방식 선택", "오늘 범위 학습 시작"],
    image: "/media/showcase/flashcard-action.jpg",
    imageAlt: "단어를 보고 몰라요 또는 알아요로 답하는 플래시카드 학습 화면",
    guideHref: "/manual#daily",
  },
  {
    key: "review",
    label: "오늘 복습",
    title: "오늘 다시 볼 단어만 확인하세요",
    description: "학습 기록을 바탕으로 앱이 오늘 복습할 단어를 모아 보여줍니다. 복습 후 다음 일정도 바로 확인합니다.",
    points: ["오늘 복습 수량 확인", "필요한 단어 복습", "결과와 다음 일정 확인"],
    image: "/media/showcase/review-today.jpg",
    imageAlt: "오늘 복습할 단어 수와 복습 시작 버튼을 보여주는 화면",
    guideHref: "/manual#review",
  },
];

export const studyModes = [
  {
    title: "플래시카드",
    axis: "익히기",
    body: "뜻과 예문을 확인하고 알아요·몰라요로 기억을 쌓습니다.",
    image: "/media/showcase/flashcard-action.jpg",
    imageAlt: "단어와 응답 버튼이 보이는 플래시카드 학습 화면",
    guideHref: "/manual#flashcard",
  },
  {
    title: "객관식 퀴즈",
    axis: "확인하기",
    body: "여러 보기 사이에서 정확한 뜻을 고르며 기억을 확인합니다.",
    image: "/media/showcase/quiz-choice.jpg",
    imageAlt: "단어의 뜻을 보기에서 고르는 객관식 퀴즈 화면",
    guideHref: "/manual#quiz",
  },
  {
    title: "스펠링 퀴즈",
    axis: "확인하기",
    body: "뜻을 보고 철자를 직접 입력해 기억을 더 단단하게 만듭니다.",
    image: "/media/showcase/quiz-spelling.jpg",
    imageAlt: "뜻을 보고 영단어 철자를 입력하는 스펠링 퀴즈 화면",
    guideHref: "/manual#spelling",
  },
] as const;

export const faqItems = [
  {
    question: "어떤 파일 형식을 가져올 수 있나요?",
    answer: "Google Sheets와 기기에 저장된 CSV·XLSX 파일을 가져올 수 있습니다. 앱 안에서 단어장을 새로 만드는 것도 가능합니다.",
  },
  {
    question: "Google Sheets를 수정하면 어떻게 반영되나요?",
    answer: "Google Sheets에서 내용을 수정한 뒤 앱에서 해당 단어장을 다시 동기화하면 변경된 단어와 뜻을 반영할 수 있습니다.",
  },
  {
    question: "AI 연결 없이도 공부할 수 있나요?",
    answer: "네. 단어장 가져오기, 플래시카드, 객관식·주관식·스펠링 퀴즈와 복습 기능은 AI 연결 없이 사용할 수 있습니다.",
  },
  {
    question: "지원 기기와 비용은 어떻게 되나요?",
    answer: "현재 Android 출시를 준비하고 있습니다. 기본 학습 기능은 무료로 제공하며, 선택 기능인 AI는 사용자가 연결한 API 제공업체의 정책과 비용이 적용됩니다.",
  },
  {
    question: "iPhone에서도 사용할 수 있나요?",
    answer: "현재 출시 준비 대상은 Android입니다. iOS 출시는 현재 계획에 포함되어 있지 않습니다.",
  },
];
