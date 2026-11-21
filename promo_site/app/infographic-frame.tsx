"use client";

import { useEffect, useState, type ReactNode } from "react";

const canvasWidth = 1080;
const canvasHeight = 1920;

export function InfographicFrame({ children }: { children: ReactNode }) {
  const [scale, setScale] = useState(1);

  useEffect(() => {
    const updateScale = () => {
      setScale(Math.min(1, window.innerWidth / canvasWidth));
    };

    updateScale();
    window.addEventListener("resize", updateScale);
    return () => window.removeEventListener("resize", updateScale);
  }, []);

  return (
    <div
      className="infographic-preview-frame"
      style={{
        width: canvasWidth * scale,
        height: canvasHeight * scale,
      }}
    >
      <div
        className="infographic-preview-canvas"
        style={{ transform: `scale(${scale})` }}
      >
        {children}
      </div>
    </div>
  );
}
