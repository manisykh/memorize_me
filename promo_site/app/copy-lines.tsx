import type { ReactNode } from "react";

type CopyLinesProps = {
  lines: readonly ReactNode[];
  className?: string;
};

/**
 * Keeps editorial line breaks stable across desktop, tablet and mobile.
 * Each line should be short enough to fit a 320px viewport at its final font size.
 */
export function CopyLines({ lines, className = "" }: CopyLinesProps) {
  return (
    <span className={`copy-lines ${className}`.trim()}>
      {lines.map((line, index) => (
        <span className="copy-line" key={index}>{line}</span>
      ))}
    </span>
  );
}
