import type { Metadata, Viewport } from "next";
import "./globals.css";
import "./manual.css";
import "./feedback.css";

const title = "Memorize Me | 시트에서 시작하는 단어 학습";
const description =
  "Google 시트를 플래시카드, 퀴즈, 맞춤 복습과 AI 시험지로 이어주는 단어 학습 앱 Memorize Me.";

const siteUrl =
  process.env.NEXT_PUBLIC_SITE_URL?.trim() ||
  process.env.URL?.trim() ||
  "https://memorize-me-guide.donmelchor2006.chatgpt.site";
const metadataBase = new URL(siteUrl);
const socialImage = new URL("/og.png", metadataBase).toString();

export const metadata: Metadata = {
  metadataBase,
  title,
  description,
  keywords: [
    "엑셀 단어장 앱",
    "구글 시트 단어 암기",
    "영어 단어장 앱",
    "플래시카드 학습",
    "스펠링 퀴즈",
    "단어 복습 앱",
  ],
  openGraph: {
    title,
    description,
    type: "website",
    locale: "ko_KR",
    images: [{ url: socialImage, width: 1792, height: 896, alt: "Memorize Me" }],
  },
  twitter: {
    card: "summary_large_image",
    title,
    description,
    images: [socialImage],
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
