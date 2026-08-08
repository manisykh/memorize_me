import type { Metadata } from "next";
import { headers } from "next/headers";
import "./globals.css";
import "./manual.css";

const title = "Memorize Me | 시트에서 시작하는 단어 학습";
const description =
  "Google 시트를 플래시카드, 퀴즈, SRS 복습과 AI 시험지로 이어주는 단어 학습 앱 Memorize Me.";

export async function generateMetadata(): Promise<Metadata> {
  const requestHeaders = await headers();
  const host =
    requestHeaders.get("x-forwarded-host") ??
    requestHeaders.get("host") ??
    "memorize-me.app";
  const protocol = requestHeaders.get("x-forwarded-proto") ?? "https";
  const origin = new URL(`${protocol}://${host}`);
  const socialImage = new URL("/og.png", origin).toString();

  return {
    metadataBase: origin,
    title,
    description,
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
}

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
