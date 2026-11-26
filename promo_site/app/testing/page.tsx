import type { Metadata } from "next";
import { getReleaseConfig } from "../../lib/site-release";
import { TestingGuide } from "./testing-guide";

export const metadata: Metadata = {
  title: "테스트 및 출시 안내 | Memorize Me",
  description: "Memorize Me 비공개 테스트 참여 조건, 신청 방법, 출시 로드맵과 자주 묻는 질문을 확인하세요.",
};

export default function TestingPage() {
  return <TestingGuide releaseConfig={getReleaseConfig()} />;
}
