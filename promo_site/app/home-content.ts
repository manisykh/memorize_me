export type JourneyKey = "import" | "learn" | "review";

export type MotionVideo = {
  src: string;
  startAt?: number;
  endAt?: number;
  sourceWidth?: number;
  sourceHeight?: number;
  cropLeft?: number;
  cropRight?: number;
  cropTop?: number;
  cropBottom?: number;
};

const landscapeRecordingCrop = {
  sourceWidth: 1920,
  sourceHeight: 1080,
  cropLeft: 718,
  cropRight: 718,
  cropTop: 40,
  cropBottom: 44,
} as const;

export type JourneyStep = {
  key: JourneyKey;
  label: string;
  title: string;
  titleLines: readonly string[];
  description: string;
  descriptionLines: readonly string[];
  points: string[];
  image: string;
  imageAlt: string;
  video?: MotionVideo;
};

export type StudyModeIconName = "flashcard" | "choice" | "spelling" | "mistakes" | "review" | "test";

type StudyMode = {
  title: string;
  icon: StudyModeIconName;
  body: string;
  bodyLines: readonly string[];
  image: string;
  imageAlt: string;
  video?: MotionVideo;
};

export const journeySteps: JourneyStep[] = [
  {
    key: "import",
    label: "단어장 준비",
    title: "정리한 단어장을 그대로 가져오세요",
    titleLines: ["정리한 단어장을", "그대로 가져오세요"],
    description: "단어와 뜻이 열로 정리된 Google Sheets·CSV·XLSX를 선택합니다. 앱에서 새 단어장을 직접 만들 수도 있습니다.",
    descriptionLines: ["단어와 뜻이 정리된 파일을 선택하세요.", "앱에서 새 단어장을 직접 만들 수도 있습니다."],
    points: ["단어·뜻 열 확인", "가져올 파일과 시트 선택", "현재 학습 단어장 지정"],
    image: "/media/feature/sheet-selection-current.svg",
    imageAlt: "가져올 시트를 선택하는 Memorize Me 화면",
    video: {
      src: "/media/video/wordbook-import.mp4",
      startAt: 0.2,
      endAt: 13.25,
      ...landscapeRecordingCrop,
    },
  },
  {
    key: "learn",
    label: "첫 학습",
    title: "학습 범위와 방식을 선택하세요",
    titleLines: ["학습 범위와 방식을", "선택하세요"],
    description: "오늘 학습할 단어장과 범위를 정한 뒤 플래시카드·객관식·스펠링 중 원하는 방식을 선택합니다.",
    descriptionLines: ["오늘 학습할 단어장과 범위를 정하세요.", "원하는 학습 방식을 선택해 시작합니다."],
    points: ["학습 단어장 선택", "새 단어·복습 범위 확인", "학습 방식 선택"],
    image: "/media/latest/learning-current.png",
    imageAlt: "오늘 복습과 플래시카드·객관식·스펠링 학습 방식을 한눈에 보여주는 학습 화면",
  },
  {
    key: "review",
    label: "오늘 복습",
    title: "오늘 다시 볼 단어만 확인하세요",
    titleLines: ["오늘 다시 볼 단어만", "확인하세요"],
    description: "학습 기록을 바탕으로 앱이 오늘 복습할 단어를 모아 보여줍니다. 복습 후 다음 일정도 바로 확인합니다.",
    descriptionLines: ["앱이 오늘 복습할 단어를 모아 보여줍니다.", "복습을 마치면 다음 일정도 바로 확인합니다."],
    points: ["오늘 복습 수량 확인", "필요한 단어 복습", "결과와 다음 일정 확인"],
    image: "/media/showcase/review-today.jpg",
    imageAlt: "오늘 복습할 단어 수와 복습 시작 버튼을 보여주는 화면",
  },
];

export const studyModes: readonly StudyMode[] = [
  {
    title: "플래시카드",
    icon: "flashcard",
    body: "뜻과 예문을 확인하고 알아요·몰라요로 기억을 쌓습니다.",
    bodyLines: ["뜻과 예문을 확인하고", "알아요·몰라요로 기억을 쌓습니다."],
    image: "/media/showcase/flashcard-action.jpg",
    imageAlt: "단어와 응답 버튼이 보이는 플래시카드 학습 화면",
    video: {
      src: "/media/video/flashcard.mp4",
      startAt: 0.2,
      endAt: 6.85,
      ...landscapeRecordingCrop,
    },
  },
  {
    title: "객관식 퀴즈",
    icon: "choice",
    body: "여러 보기 사이에서 정확한 뜻을 고르며 기억을 확인합니다.",
    bodyLines: ["여러 보기에서 정확한 뜻을 고르며", "기억을 확인합니다."],
    image: "/media/showcase/quiz-choice.jpg",
    imageAlt: "단어의 뜻을 보기에서 고르는 객관식 퀴즈 화면",
    video: {
      src: "/media/video/quiz-choice.mp4",
      startAt: 0.2,
      endAt: 10.15,
      ...landscapeRecordingCrop,
    },
  },
  {
    title: "스펠링 퀴즈",
    icon: "spelling",
    body: "뜻을 보고 철자를 직접 입력해 기억을 더 단단하게 만듭니다.",
    bodyLines: ["뜻을 보고 철자를 직접 입력해", "기억을 더 단단하게 만듭니다."],
    image: "/media/showcase/quiz-spelling.jpg",
    imageAlt: "뜻을 보고 영단어 철자를 입력하는 스펠링 퀴즈 화면",
    video: {
      src: "/media/video/quiz-spelling.mp4",
      startAt: 0.2,
      endAt: 25.6,
      ...landscapeRecordingCrop,
    },
  },
  {
    title: "오답노트",
    icon: "mistakes",
    body: "틀린 단어와 다시 확인할 기록을 모아 취약한 부분을 반복합니다.",
    bodyLines: ["틀린 단어와 다시 확인할 기록을 모아", "취약한 부분을 반복합니다."],
    image: "/media/current-20261107/learning-overview.jpg",
    imageAlt: "누적 오답과 다시 확인할 학습 기록을 보여주는 학습 화면",
  },
  {
    title: "복습하기",
    icon: "review",
    body: "학습 결과에 맞춰 오늘 필요한 단어와 다음 복습 일정을 확인합니다.",
    bodyLines: ["오늘 필요한 단어를 모아 복습하고", "다음 복습 일정까지 확인합니다."],
    image: "/media/showcase/review-today.jpg",
    imageAlt: "오늘 복습할 단어 수와 복습 시작 버튼을 보여주는 화면",
  },
  {
    title: "시험지 만들기",
    icon: "test",
    body: "학습할 단어를 골라 PDF·Excel·HTML 시험지로 만들고 공유합니다.",
    bodyLines: ["학습할 단어를 골라 시험지로 만들고", "PDF·Excel·HTML로 공유합니다."],
    image: "/media/manual/pdf-options.jpg",
    imageAlt: "시험지 파일 형식과 출력 구성을 선택하는 화면",
    video: {
      src: "/media/video/test-sheet.mp4",
      startAt: 0.2,
      endAt: 15.68,
      ...landscapeRecordingCrop,
    },
  },
];

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
    answer: "현재는 Android 출시를 먼저 준비하고 있습니다. iOS 버전도 사용자 요청과 운영 여건을 살펴 추후 지원을 검토할 예정입니다.",
  },
];
