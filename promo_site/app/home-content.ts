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

const homepageVideoSize = {
  sourceWidth: 720,
  sourceHeight: 1440,
} as const;

export type PreparationIconName = "import" | "create" | "builtin";

export type PreparationOption = {
  icon: PreparationIconName;
  title: string;
  titleLines: readonly string[];
  description: string;
  descriptionLines: readonly string[];
  videoStartsAt: number;
  caption: string;
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

export const preparationOptions: readonly PreparationOption[] = [
  {
    icon: "builtin",
    title: "기본 단어장으로 시작하기",
    titleLines: ["기본 단어장으로", "시작하기"],
    description: "필수 영어단어 6000을 1,000개씩 여섯 단계로 나누어 학습합니다.",
    descriptionLines: ["필수 영어단어 6000을", "여섯 단계로 나누어 학습합니다."],
    videoStartsAt: 0,
    caption: "필수 영어단어 6000으로 시작하기",
  },
  {
    icon: "import",
    title: "내 단어장 가져오기",
    titleLines: ["내 단어장", "가져오기"],
    description: "Google Sheets·CSV·XLSX에 정리한 단어와 뜻을 그대로 불러옵니다.",
    descriptionLines: ["Google Sheets·CSV·XLSX의", "단어와 뜻을 그대로 불러옵니다."],
    videoStartsAt: 8.6,
    caption: "Google Sheets에서 내 단어장 가져오기",
  },
  {
    icon: "create",
    title: "직접 만들기",
    titleLines: ["직접 만들기"],
    description: "필요한 단어와 뜻을 앱에서 바로 입력해 나만의 단어장을 만듭니다.",
    descriptionLines: ["필요한 단어와 뜻을 입력해", "나만의 단어장을 만듭니다."],
    videoStartsAt: 18.8,
    caption: "앱에서 나만의 단어장 만들기",
  },
];

export const preparationVisual = {
  image: "/media/video/posters/wordbook-import.jpg",
  imageAlt: "기본 단어장, 내 단어장 가져오기와 직접 만들기 과정을 보여주는 Memorize Me 화면",
  video: {
    src: "/media/video/wordbook-import.mp4",
    startAt: 0.1,
    endAt: 34.45,
    ...homepageVideoSize,
  } satisfies MotionVideo,
} as const;

export const studyModes: readonly StudyMode[] = [
  {
    title: "플래시카드",
    icon: "flashcard",
    body: "뜻과 예문을 확인하고 알아요·몰라요로 기억을 쌓습니다.",
    bodyLines: ["뜻과 예문을 확인하고", "알아요·몰라요로 기억을 쌓습니다."],
    image: "/media/video/posters/flashcard.jpg",
    imageAlt: "단어와 응답 버튼이 보이는 플래시카드 학습 화면",
    video: {
      src: "/media/video/flashcard.mp4",
      startAt: 0.1,
      endAt: 13.94,
      ...homepageVideoSize,
    },
  },
  {
    title: "객관식 퀴즈",
    icon: "choice",
    body: "여러 보기 사이에서 정확한 뜻을 고르며 기억을 확인합니다.",
    bodyLines: ["여러 보기에서 정확한 뜻을 고르며", "기억을 확인합니다."],
    image: "/media/video/posters/quiz-choice.jpg",
    imageAlt: "단어의 뜻을 보기에서 고르는 객관식 퀴즈 화면",
    video: {
      src: "/media/video/quiz-choice.mp4",
      startAt: 0.1,
      endAt: 19.17,
      ...homepageVideoSize,
    },
  },
  {
    title: "스펠링 퀴즈",
    icon: "spelling",
    body: "뜻을 보고 철자를 직접 입력해 기억을 더 단단하게 만듭니다.",
    bodyLines: ["뜻을 보고 철자를 직접 입력해", "기억을 더 단단하게 만듭니다."],
    image: "/media/video/posters/quiz-spelling.jpg",
    imageAlt: "뜻을 보고 영단어 철자를 입력하는 스펠링 퀴즈 화면",
    video: {
      src: "/media/video/quiz-spelling.mp4",
      startAt: 0.1,
      endAt: 19.09,
      ...homepageVideoSize,
    },
  },
  {
    title: "오답노트",
    icon: "mistakes",
    body: "틀린 단어와 다시 확인할 기록을 모아 취약한 부분을 반복합니다.",
    bodyLines: ["틀린 단어와 다시 확인할 기록을 모아", "취약한 부분을 반복합니다."],
    image: "/media/video/posters/mistakes.jpg",
    imageAlt: "누적 오답과 다시 확인할 학습 기록을 보여주는 학습 화면",
    video: {
      src: "/media/video/mistakes.mp4",
      startAt: 0.1,
      endAt: 10.55,
      ...homepageVideoSize,
    },
  },
  {
    title: "복습하기",
    icon: "review",
    body: "학습 결과에 맞춰 오늘 필요한 단어와 다음 복습 일정을 확인합니다.",
    bodyLines: ["오늘 필요한 단어를 모아 복습하고", "다음 복습 일정까지 확인합니다."],
    image: "/media/video/posters/review.jpg",
    imageAlt: "오늘 복습할 단어 수와 복습 시작 버튼을 보여주는 화면",
    video: {
      src: "/media/video/review.mp4",
      startAt: 0.1,
      endAt: 11.7,
      ...homepageVideoSize,
    },
  },
  {
    title: "시험지 만들기",
    icon: "test",
    body: "학습할 단어를 골라 PDF·Excel·HTML 시험지로 만들고 공유합니다.",
    bodyLines: ["학습할 단어를 골라 시험지로 만들고", "PDF·Excel·HTML로 공유합니다."],
    image: "/media/video/posters/test-sheet.jpg",
    imageAlt: "시험지 파일 형식과 출력 구성을 선택하는 화면",
    video: {
      src: "/media/video/test-sheet.mp4",
      startAt: 0.1,
      endAt: 14.9,
      ...homepageVideoSize,
    },
  },
];

type FaqItem = {
  question: string;
  answer: string;
  answerLines?: readonly string[];
};

export const faqItems: readonly FaqItem[] = [
  {
    question: "어떤 파일 형식을 가져올 수 있나요?",
    answer: "Google Sheets와 기기에 저장된 CSV·XLSX 파일을 가져올 수 있습니다. 앱 안에서 단어장을 새로 만드는 것도 가능합니다.",
    answerLines: [
      "Google Sheets와 기기에 저장된 CSV·XLSX 파일을 가져올 수 있습니다.",
      "앱 안에서 단어장을 새로 만드는 것도 가능합니다.",
    ],
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
    answer: "현재 Android 출시를 준비하고 있습니다. 초기 출시 혜택 기간에 다운로드한 사용자는 주요 학습 기능을 평생 무료로 이용할 수 있습니다. 혜택 기간 종료 후 새로 다운로드하는 사용자는 광고를 보거나 일부 기능을 유료로 이용할 수 있습니다. 적용 기간과 기준은 출시 전에 안내합니다. AI 기능은 연결한 API 제공업체의 정책과 비용을 따릅니다.",
  },
  {
    question: "iPhone에서도 사용할 수 있나요?",
    answer: "현재는 Android 출시를 먼저 준비하고 있습니다. iOS 버전도 사용자 요청과 운영 여건을 살펴 추후 지원을 검토할 예정입니다.",
  },
];
