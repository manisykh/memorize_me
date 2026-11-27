import type { Metadata } from "next";
import { LegacyAdminRedirect } from "./legacy-admin-redirect";

export const metadata: Metadata = {
  title: "관리자 페이지로 이동 | Memorize Me",
  robots: { index: false, follow: false },
};

export default function Page() {
  return <LegacyAdminRedirect />;
}
