import { faqItems } from "./home-content";
import { HomeLanding } from "./home-interactions";
import { getReleaseConfig, releasePresentation } from "../lib/site-release";

export default function HomePage() {
  const releaseConfig = getReleaseConfig();
  const state = releasePresentation(releaseConfig);
  const productFaq = faqItems.map((item) => item.question === "지원 기기와 비용은 어떻게 되나요?" ? { ...item, answer: `${state.label}. ${item.answer.replace("현재 Android 출시를 준비하고 있습니다. ", "")}` } : item);
  const faqStructuredData = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: productFaq.map((item) => ({
      "@type": "Question",
      name: item.question,
      acceptedAnswer: {
        "@type": "Answer",
        text: item.answer,
      },
    })),
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqStructuredData) }}
      />
      <HomeLanding releaseConfig={releaseConfig} />
    </>
  );
}
