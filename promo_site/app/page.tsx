import { faqItems } from "./home-content";
import { HomeLanding } from "./home-interactions";

export default function HomePage() {
  const googlePlayUrl = process.env.NEXT_PUBLIC_GOOGLE_PLAY_URL?.trim();
  const supportEmail = process.env.NEXT_PUBLIC_SUPPORT_EMAIL?.trim();
  const faqStructuredData = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqItems.map((item) => ({
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
      <HomeLanding googlePlayUrl={googlePlayUrl} supportEmail={supportEmail} />
    </>
  );
}
