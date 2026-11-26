import type { Metadata } from "next";
import { TesterAdmin } from "./tester-admin";
export const metadata: Metadata = { title: "테스트 신청 관리 | Memorize Me", robots: { index: false, follow: false } };
export default function Page() { return <TesterAdmin />; }
