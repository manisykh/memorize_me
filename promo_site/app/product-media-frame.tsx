import type { ReactNode } from "react";

export function ProductMediaFrame({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`product-media-frame ${className}`.trim()}>{children}</div>;
}
