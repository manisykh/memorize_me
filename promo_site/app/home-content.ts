export type JourneyKey = "import" | "learn" | "review";

export type JourneyStep = {
  key: JourneyKey;
  shortLabel: string;
  title: string;
  description: string;
  points: string[];
  image: string;
  imageAlt: string;
  imageLabel: string;
  guideHref: string;
};

export const journeySteps: JourneyStep[] = [
  {
    key: "import",
    shortLabel: "단어장 준비",
    title: "단어와 뜻을 준비해 가져와요",
    description:
      "단어와 뜻이 열로 정리된 Google Sheets, CSV, XLSX를 준비하세요. 앱에서 새 단어장을 직접 만들어도 됩니다.",
    points: ["단어·뜻 열 확인", "가져올 파일과 시트 선택", "현재 학습 단어장 지정"],
    image: "/media/feature/sheet-selection-current.svg",
    imageAlt: "가져올 시트를 여러 개 선택하는 최신 Memorize Me 화면",
    imageLabel: "학습할 시트 선택",
    guideHref: "/manual#wordbook",
  },
  {
    key: "learn",
    shortLabel: "첫 학습",
    title: "단어장을 고르고 첫 학습을 시작해요",
    description:
      "홈에서 학습할 단어장을 선택한 뒤 플래시카드나 퀴즈 등 원하는 방식을 골라 학습을 시작하세요.",
    points: ["학습 단어장 선택", "학습 방식 선택", "오늘 범위 학습 시작"],
    image: "/media/current-20261107/flashcard-learning.jpg",
    imageAlt: "학습 진행률과 기억 단계를 함께 보여주는 최신 플래시카드 학습 화면",
    imageLabel: "플래시카드 학습",
    guideHref: "/manual#daily",
  },
  {
    key: "review",
    shortLabel: "오늘 복습",
    title: "오늘 복습할 단어를 확인해요",
    description:
      "학습 결과를 바탕으로 앱이 오늘 다시 볼 단어를 정리합니다. 복습을 마치고 다음 일정을 확인하세요.",
    points: ["복습할 단어 확인", "오늘 복습 진행", "결과와 다음 일정 확인"],
    image: "/media/current-20261107/learning-overview.jpg",
    imageAlt: "오늘의 복습 수량과 단어장 학습 기록을 보여주는 최신 학습 화면",
    imageLabel: "오늘 복습과 학습 기록",
    guideHref: "/manual#review",
  },
];

export const studyModes = [
  {
    title: "플래시카드",
    body: "뜻과 예문을 확인하며 빠르게 반복합니다.",
    image: "/media/current-20261107/flashcard-learning.jpg",
    imageAlt: "최신 Memorize Me 플래시카드 학습 화면",
  },
  {
    title: "객관식 퀴즈",
    body: "보기 사이에서 정확한 의미를 구분합니다.",
    image: "/media/feature/quiz-multiple-choice-current.jpg",
    imageAlt: "최신 Memorize Me 객관식 퀴즈 화면",
  },
  {
    title: "스펠링 퀴즈",
    body: "철자를 직접 입력해 기억을 단단하게 만듭니다.",
    image: "/media/feature/quiz-spelling-current.jpg",
    imageAlt: "최신 Memorize Me 스펠링 퀴즈 화면",
  },
] as const;

export const faqItems = [
  {
    question: "어떤 파일 형식을 가져올 수 있나요?",
    answer:
      "Google Sheets와 기기에 저장된 CSV·XLSX 파일을 가져올 수 있습니다. 앱 안에서 단어장을 새로 만드는 것도 가능합니다.",
  },
  {
    question: "Google Sheets를 수정하면 어떻게 반영되나요?",
    answer:
      "Google Sheets에서 내용을 수정한 뒤 앱에서 해당 단어장을 다시 동기화하면 변경된 단어와 뜻을 반영할 수 있습니다.",
  },
  {
    question: "AI 연결 없이도 공부할 수 있나요?",
    answer:
      "네. 단어장 가져오기, 플래시카드, 객관식·주관식·스펠링 퀴즈와 복습 기능은 AI 연결 없이 사용할 수 있습니다.",
  },
  {
    question: "지원 기기와 비용은 어떻게 되나요?",
    answer:
      "현재 Android 출시를 준비하고 있습니다. 기본 학습 기능은 무료로 제공하며, 선택 기능인 AI는 사용자가 발급한 무료 API 또는 보유한 유료 API의 정책과 비용이 적용됩니다.",
  },
];
