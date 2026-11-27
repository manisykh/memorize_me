import type { Metadata } from "next";
import { AdminDashboard } from "./admin-dashboard";

export const metadata: Metadata = {
  title: "관리자 페이지 | Memorize Me",
  robots: { index: false, follow: false },
};

export default function Page() {
  return <AdminDashboard />;
}
