"use client";

import { useState, useRef, useCallback, useEffect } from "react";
import { toPng } from "html-to-image";

// ============================================================
// CONSTANTS
// ============================================================
const W = 1320;
const H = 2868;

const SIZES = [
  { label: '6.9"', w: 1320, h: 2868 },
  { label: '6.5"', w: 1284, h: 2778 },
  { label: '6.3"', w: 1206, h: 2622 },
  { label: '6.1"', w: 1125, h: 2436 },
] as const;

// Phone mockup measurements
const MK_W = 1022;
const MK_H = 2082;
const SC_L = (52 / MK_W) * 100;
const SC_T = (46 / MK_H) * 100;
const SC_W = (918 / MK_W) * 100;
const SC_H = (1990 / MK_H) * 100;
const SC_RX = (126 / 918) * 100;
const SC_RY = (126 / 1990) * 100;

const FONT =
  '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", system-ui, sans-serif';

// ============================================================
// STYLE CONFIGS
// ============================================================
type StyleKey = "clean" | "dark";

interface StyleConfig {
  name: string;
  backgrounds: string[];
  textColor: (i: number) => string;
  labelColor: (i: number) => string;
  labelBg: (i: number) => string;
  decoColor: (i: number) => string;
  decoColor2: (i: number) => string;
}

const STYLES: Record<StyleKey, StyleConfig> = {
  clean: {
    name: "Clean / Minimal",
    backgrounds: [
      "linear-gradient(170deg, #B8E6C8 0%, #D4EDDA 30%, #F0FFF4 70%, #FFFFFF 100%)",
      "linear-gradient(170deg, #C8E6CF 0%, #E0F2E9 30%, #F5FFF7 70%, #FAFAFA 100%)",
      "linear-gradient(170deg, #A8D8B9 0%, #C8E6C9 30%, #E8F5E9 70%, #FFFFFF 100%)",
      "linear-gradient(170deg, #D4EDDA 0%, #E0F2E9 30%, #F0FFF4 70%, #FFFFFF 100%)",
      "linear-gradient(170deg, #B8E6C8 0%, #D4EDDA 30%, #E8F5E9 70%, #FAFAFA 100%)",
      "linear-gradient(170deg, #C8E6CF 0%, #E0F2E9 30%, #F5FFF7 70%, #FFFFFF 100%)",
    ],
    textColor: () => "#1B4332",
    labelColor: () => "#2D6A4F",
    labelBg: () => "rgba(27, 67, 50, 0.08)",
    decoColor: () => "rgba(82, 183, 136, 0.18)",
    decoColor2: () => "rgba(27, 67, 50, 0.06)",
  },
  dark: {
    name: "Dark / Moody",
    backgrounds: [
      "linear-gradient(170deg, #050F09 0%, #0A1F14 30%, #143D29 70%, #1B4332 100%)",
      "linear-gradient(170deg, #071A10 0%, #0D2818 30%, #1B4332 70%, #2D6A4F 100%)",
      "linear-gradient(170deg, #050F09 0%, #0A1F14 30%, #0F2E1F 70%, #1B4332 100%)",
      "linear-gradient(170deg, #071A10 0%, #0D2818 30%, #143D29 70%, #2D6A4F 100%)",
      "linear-gradient(170deg, #050F09 0%, #0A1F14 30%, #143D29 70%, #1B4332 100%)",
      "linear-gradient(170deg, #071A10 0%, #0D2818 30%, #1B4332 70%, #2D6A4F 100%)",
    ],
    textColor: () => "#FFFFFF",
    labelColor: () => "#52B788",
    labelBg: () => "rgba(82, 183, 136, 0.12)",
    decoColor: () => "rgba(82, 183, 136, 0.08)",
    decoColor2: () => "rgba(82, 183, 136, 0.04)",
  },
};

// ============================================================
// SLIDES DATA
// ============================================================
interface SlideData {
  id: string;
  label: string;
  headline: string;
  screenshots: string[];
}

const SLIDES: SlideData[] = [
  {
    id: "hero",
    label: "QuickSpend",
    headline: "Spend Smart,\nSpeak Easy",
    screenshots: ["/screenshots/home.png"],
  },
  {
    id: "voice",
    label: "Voice Input",
    headline: "Just Say It.\nWe'll Log It.",
    screenshots: ["/screenshots/voice.png"],
  },
  {
    id: "dashboard",
    label: "Overview",
    headline: "Your Money\nAt a Glance",
    screenshots: ["/screenshots/home.png", "/screenshots/home2.png"],
  },
  {
    id: "transactions",
    label: "Calendar",
    headline: "Every Day,\nAccounted For",
    screenshots: ["/screenshots/transactions.png"],
  },
  {
    id: "reports",
    label: "Reports",
    headline: "Know Where\nIt All Goes",
    screenshots: ["/screenshots/report.png"],
  },
  {
    id: "categories",
    label: "Categories",
    headline: "Organized\nYour Way",
    screenshots: ["/screenshots/categories.png"],
  },
];

// ============================================================
// PHONE COMPONENT
// ============================================================
function Phone({
  src,
  alt = "",
  style,
  className = "",
}: {
  src: string;
  alt?: string;
  style?: React.CSSProperties;
  className?: string;
}) {
  return (
    <div
      className={`relative ${className}`}
      style={{ aspectRatio: `${MK_W}/${MK_H}`, ...style }}
    >
      <img
        src="/mockup.png"
        alt=""
        className="block w-full h-full"
        draggable={false}
      />
      <div
        className="absolute z-10 overflow-hidden"
        style={{
          left: `${SC_L}%`,
          top: `${SC_T}%`,
          width: `${SC_W}%`,
          height: `${SC_H}%`,
          borderRadius: `${SC_RX}% / ${SC_RY}%`,
        }}
      >
        <img
          src={src}
          alt={alt}
          className="block w-full h-full object-cover object-top"
          draggable={false}
        />
      </div>
    </div>
  );
}

// ============================================================
// CAPTION COMPONENT
// ============================================================
function Caption({
  label,
  headline,
  textColor,
  labelColor,
  labelBg,
  align = "center",
  style,
}: {
  label: string;
  headline: string;
  textColor: string;
  labelColor: string;
  labelBg: string;
  align?: "left" | "center" | "right";
  style?: React.CSSProperties;
}) {
  return (
    <div style={{ textAlign: align, ...style }}>
      <div
        style={{
          display: "inline-block",
          fontSize: W * 0.028,
          fontWeight: 600,
          color: labelColor,
          background: labelBg,
          padding: `${W * 0.008}px ${W * 0.024}px`,
          borderRadius: W * 0.02,
          marginBottom: W * 0.018,
          letterSpacing: "0.02em",
          textTransform: "uppercase",
        }}
      >
        {label}
      </div>
      <div
        style={{
          fontSize: W * 0.09,
          fontWeight: 700,
          color: textColor,
          lineHeight: 1.0,
          letterSpacing: "-0.02em",
          whiteSpace: "pre-line",
        }}
      >
        {headline}
      </div>
    </div>
  );
}

// ============================================================
// DECORATIVE ELEMENTS
// ============================================================
function GlowCircle({
  color,
  size,
  style,
}: {
  color: string;
  size: number;
  style?: React.CSSProperties;
}) {
  return (
    <div
      style={{
        position: "absolute",
        width: size,
        height: size,
        borderRadius: "50%",
        background: `radial-gradient(circle, ${color} 0%, transparent 70%)`,
        pointerEvents: "none",
        ...style,
      }}
    />
  );
}

function SmallCircle({
  color,
  size,
  style,
}: {
  color: string;
  size: number;
  style?: React.CSSProperties;
}) {
  return (
    <div
      style={{
        position: "absolute",
        width: size,
        height: size,
        borderRadius: "50%",
        background: color,
        pointerEvents: "none",
        ...style,
      }}
    />
  );
}

function Ring({
  color,
  size,
  borderWidth,
  style,
}: {
  color: string;
  size: number;
  borderWidth: number;
  style?: React.CSSProperties;
}) {
  return (
    <div
      style={{
        position: "absolute",
        width: size,
        height: size,
        borderRadius: "50%",
        border: `${borderWidth}px solid ${color}`,
        pointerEvents: "none",
        ...style,
      }}
    />
  );
}

// ============================================================
// SLIDE LAYOUTS
// ============================================================

function SlideHero({ style: sk }: { style: StyleConfig; index: number }) {
  const i = 0;
  return (
    <>
      <GlowCircle
        color={sk.decoColor(i)}
        size={W * 1.2}
        style={{ bottom: "-20%", left: "50%", transform: "translateX(-50%)" }}
      />
      <SmallCircle
        color={sk.decoColor(i)}
        size={W * 0.06}
        style={{ top: "18%", left: "8%" }}
      />
      <SmallCircle
        color={sk.decoColor(i)}
        size={W * 0.04}
        style={{ top: "12%", right: "12%" }}
      />
      <SmallCircle
        color={sk.decoColor2(i)}
        size={W * 0.08}
        style={{ top: "30%", right: "5%" }}
      />
      <Ring
        color={sk.decoColor(i)}
        size={W * 0.16}
        borderWidth={3}
        style={{ top: "22%", left: "78%" }}
      />

      {/* App icon */}
      <div
        style={{
          position: "absolute",
          top: W * 0.08,
          left: "50%",
          transform: "translateX(-50%)",
          zIndex: 2,
        }}
      >
        <img
          src="/app-icon.png"
          alt="QuickSpend"
          style={{
            width: W * 0.12,
            height: W * 0.12,
            borderRadius: W * 0.028,
            boxShadow: "0 8px 40px rgba(0,0,0,0.15)",
          }}
          draggable={false}
        />
      </div>

      {/* Caption */}
      <div
        style={{
          position: "absolute",
          top: W * 0.23,
          left: 0,
          right: 0,
          zIndex: 2,
        }}
      >
        <Caption
          label={SLIDES[0].label}
          headline={SLIDES[0].headline}
          textColor={sk.textColor(i)}
          labelColor={sk.labelColor(i)}
          labelBg={sk.labelBg(i)}
        />
      </div>

      <Phone
        src={SLIDES[0].screenshots[0]}
        style={{
          position: "absolute",
          bottom: 0,
          left: "50%",
          transform: "translateX(-50%) translateY(14%)",
          width: "82%",
          zIndex: 1,
        }}
      />
    </>
  );
}

function SlideVoice({ style: sk }: { style: StyleConfig; index: number }) {
  const i = 1;
  return (
    <>
      {[...Array(5)].map((_, j) => (
        <div
          key={`wave-l-${j}`}
          style={{
            position: "absolute",
            left: W * 0.04,
            top: `${42 + j * 4}%`,
            width: W * 0.06,
            height: W * 0.008,
            borderRadius: W * 0.004,
            background: sk.decoColor(i),
            opacity: 0.6 + j * 0.08,
          }}
        />
      ))}
      {[...Array(5)].map((_, j) => (
        <div
          key={`wave-r-${j}`}
          style={{
            position: "absolute",
            right: W * 0.04,
            top: `${40 + j * 4.5}%`,
            width: W * 0.04 + j * W * 0.008,
            height: W * 0.008,
            borderRadius: W * 0.004,
            background: sk.decoColor(i),
            opacity: 0.5 + j * 0.1,
          }}
        />
      ))}
      <GlowCircle
        color={sk.decoColor(i)}
        size={W * 0.8}
        style={{ bottom: "5%", right: "-20%" }}
      />
      <Ring
        color={sk.decoColor(i)}
        size={W * 0.2}
        borderWidth={3}
        style={{ top: "15%", right: "8%" }}
      />

      <div
        style={{
          position: "absolute",
          top: W * 0.1,
          left: W * 0.07,
          zIndex: 2,
        }}
      >
        <Caption
          label={SLIDES[1].label}
          headline={SLIDES[1].headline}
          textColor={sk.textColor(i)}
          labelColor={sk.labelColor(i)}
          labelBg={sk.labelBg(i)}
          align="left"
        />
      </div>

      <Phone
        src={SLIDES[1].screenshots[0]}
        style={{
          position: "absolute",
          bottom: 0,
          left: "54%",
          transform: "translateX(-50%) translateY(10%)",
          width: "78%",
          zIndex: 1,
        }}
      />
    </>
  );
}

function SlideDashboard({ style: sk }: { style: StyleConfig; index: number }) {
  const i = 2;
  return (
    <>
      <GlowCircle
        color={sk.decoColor(i)}
        size={W * 1.0}
        style={{ bottom: "-10%", left: "-30%" }}
      />
      <SmallCircle
        color={sk.decoColor(i)}
        size={W * 0.05}
        style={{ top: "8%", right: "10%" }}
      />
      <Ring
        color={sk.decoColor(i)}
        size={W * 0.12}
        borderWidth={2}
        style={{ top: "14%", left: "6%" }}
      />

      <div
        style={{
          position: "absolute",
          top: W * 0.08,
          left: 0,
          right: 0,
          zIndex: 2,
        }}
      >
        <Caption
          label={SLIDES[2].label}
          headline={SLIDES[2].headline}
          textColor={sk.textColor(i)}
          labelColor={sk.labelColor(i)}
          labelBg={sk.labelBg(i)}
        />
      </div>

      {/* Back phone */}
      <Phone
        src={SLIDES[2].screenshots[1]}
        style={{
          position: "absolute",
          bottom: 0,
          left: "-8%",
          width: "65%",
          transform: "rotate(-4deg) translateY(8%)",
          opacity: 0.55,
          zIndex: 0,
        }}
      />

      {/* Front phone */}
      <Phone
        src={SLIDES[2].screenshots[0]}
        style={{
          position: "absolute",
          bottom: 0,
          right: "-4%",
          width: "82%",
          transform: "translateY(10%)",
          zIndex: 1,
        }}
      />
    </>
  );
}

function SlideTransactions({
  style: sk,
}: {
  style: StyleConfig;
  index: number;
}) {
  const i = 3;
  return (
    <>
      {[...Array(4)].map((_, r) =>
        [...Array(3)].map((_, c) => (
          <SmallCircle
            key={`dot-${r}-${c}`}
            color={sk.decoColor(i)}
            size={W * 0.012}
            style={{
              top: `${10 + r * 6}%`,
              right: `${5 + c * 5}%`,
            }}
          />
        ))
      )}
      <GlowCircle
        color={sk.decoColor(i)}
        size={W * 0.9}
        style={{ bottom: "0%", left: "50%", transform: "translateX(-50%)" }}
      />
      <SmallCircle
        color={sk.decoColor(i)}
        size={W * 0.07}
        style={{ top: "32%", left: "5%" }}
      />

      <div
        style={{
          position: "absolute",
          top: W * 0.08,
          left: W * 0.07,
          zIndex: 2,
        }}
      >
        <Caption
          label={SLIDES[3].label}
          headline={SLIDES[3].headline}
          textColor={sk.textColor(i)}
          labelColor={sk.labelColor(i)}
          labelBg={sk.labelBg(i)}
          align="left"
        />
      </div>

      <Phone
        src={SLIDES[3].screenshots[0]}
        style={{
          position: "absolute",
          bottom: 0,
          left: "50%",
          transform: "translateX(-50%) translateY(12%)",
          width: "84%",
          zIndex: 1,
        }}
      />
    </>
  );
}

function SlideReports({ style: sk }: { style: StyleConfig; index: number }) {
  const i = 4;
  return (
    <>
      <Ring
        color={sk.decoColor(i)}
        size={W * 0.5}
        borderWidth={W * 0.04}
        style={{ top: "6%", left: "-15%", opacity: 0.4 }}
      />
      <GlowCircle
        color={sk.decoColor(i)}
        size={W * 0.8}
        style={{ bottom: "-5%", right: "-25%" }}
      />
      <SmallCircle
        color={sk.decoColor(i)}
        size={W * 0.035}
        style={{ top: "20%", right: "8%" }}
      />
      <SmallCircle
        color={sk.decoColor2(i)}
        size={W * 0.06}
        style={{ top: "10%", right: "20%" }}
      />

      <div
        style={{
          position: "absolute",
          top: W * 0.08,
          right: W * 0.07,
          zIndex: 2,
        }}
      >
        <Caption
          label={SLIDES[4].label}
          headline={SLIDES[4].headline}
          textColor={sk.textColor(i)}
          labelColor={sk.labelColor(i)}
          labelBg={sk.labelBg(i)}
          align="right"
        />
      </div>

      <Phone
        src={SLIDES[4].screenshots[0]}
        style={{
          position: "absolute",
          bottom: 0,
          left: "46%",
          transform: "translateX(-50%) translateY(12%)",
          width: "82%",
          zIndex: 1,
        }}
      />
    </>
  );
}

function SlideCategories({
  style: sk,
}: {
  style: StyleConfig;
  index: number;
}) {
  const i = 5;
  const features = [
    "Multi-Currency",
    "4 Languages",
    "Recurring Expenses",
    "Smart Reports",
    "Dark Mode",
    "Custom Categories",
  ];
  return (
    <>
      <GlowCircle
        color={sk.decoColor(i)}
        size={W * 0.9}
        style={{ bottom: "-15%", left: "-20%" }}
      />
      <SmallCircle
        color={sk.decoColor(i)}
        size={W * 0.04}
        style={{ top: "10%", left: "10%" }}
      />

      <div
        style={{
          position: "absolute",
          top: W * 0.07,
          left: 0,
          right: 0,
          zIndex: 2,
        }}
      >
        <Caption
          label={SLIDES[5].label}
          headline={SLIDES[5].headline}
          textColor={sk.textColor(i)}
          labelColor={sk.labelColor(i)}
          labelBg={sk.labelBg(i)}
        />
      </div>

      {/* Feature pills — left */}
      <div
        style={{
          position: "absolute",
          top: "34%",
          left: W * 0.04,
          zIndex: 2,
          display: "flex",
          flexDirection: "column",
          gap: W * 0.012,
        }}
      >
        {features.slice(0, 3).map((f) => (
          <div
            key={f}
            style={{
              fontSize: W * 0.024,
              fontWeight: 600,
              color: sk.labelColor(i),
              background: sk.labelBg(i),
              padding: `${W * 0.008}px ${W * 0.02}px`,
              borderRadius: W * 0.015,
              whiteSpace: "nowrap",
            }}
          >
            {f}
          </div>
        ))}
      </div>

      {/* Feature pills — right */}
      <div
        style={{
          position: "absolute",
          top: "35%",
          right: W * 0.04,
          zIndex: 2,
          display: "flex",
          flexDirection: "column",
          alignItems: "flex-end",
          gap: W * 0.012,
        }}
      >
        {features.slice(3).map((f) => (
          <div
            key={f}
            style={{
              fontSize: W * 0.024,
              fontWeight: 600,
              color: sk.labelColor(i),
              background: sk.labelBg(i),
              padding: `${W * 0.008}px ${W * 0.02}px`,
              borderRadius: W * 0.015,
              whiteSpace: "nowrap",
            }}
          >
            {f}
          </div>
        ))}
      </div>

      <Phone
        src={SLIDES[5].screenshots[0]}
        style={{
          position: "absolute",
          bottom: 0,
          left: "50%",
          transform: "translateX(-50%) translateY(14%)",
          width: "74%",
          zIndex: 1,
        }}
      />
    </>
  );
}

// ============================================================
// SLIDE RENDERER
// ============================================================
const SLIDE_COMPONENTS = [
  SlideHero,
  SlideVoice,
  SlideDashboard,
  SlideTransactions,
  SlideReports,
  SlideCategories,
];

function SlideContent({
  index,
  styleKey,
}: {
  index: number;
  styleKey: StyleKey;
}) {
  const sk = STYLES[styleKey];
  const Component = SLIDE_COMPONENTS[index];

  return (
    <div
      style={{
        width: W,
        height: H,
        position: "relative",
        overflow: "hidden",
        background: sk.backgrounds[index],
        fontFamily: FONT,
      }}
    >
      <Component style={sk} index={index} />
    </div>
  );
}

// ============================================================
// PREVIEW CARD
// ============================================================
function PreviewCard({
  index,
  styleKey,
  onExport,
}: {
  index: number;
  styleKey: StyleKey;
  onExport: (index: number) => void;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0.15);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const observer = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const cw = entry.contentRect.width;
        setScale(cw / W);
      }
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  return (
    <div className="group relative">
      <div
        ref={containerRef}
        className="w-full rounded-xl overflow-hidden shadow-lg cursor-pointer relative"
        style={{ aspectRatio: `${W}/${H}` }}
        onClick={() => onExport(index)}
      >
        <div
          style={{
            width: W,
            height: H,
            transform: `scale(${scale})`,
            transformOrigin: "top left",
          }}
        >
          <SlideContent index={index} styleKey={styleKey} />
        </div>
        <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center opacity-0 group-hover:opacity-100">
          <span className="bg-white/90 text-gray-900 px-4 py-2 rounded-lg font-semibold text-sm shadow-lg">
            Click to Export
          </span>
        </div>
      </div>
      <p className="text-center text-sm text-gray-500 mt-2 font-medium">
        {SLIDES[index].id.charAt(0).toUpperCase() + SLIDES[index].id.slice(1)}
      </p>
    </div>
  );
}

// ============================================================
// MAIN PAGE
// ============================================================
export default function ScreenshotsPage() {
  const [styleKey, setStyleKey] = useState<StyleKey>("clean");
  const [sizeIndex, setSizeIndex] = useState(0);
  const [exporting, setExporting] = useState(false);
  const [status, setStatus] = useState("");
  const exportRefs = useRef<(HTMLDivElement | null)[]>([]);

  const exportSlide = useCallback(
    async (index: number, size: (typeof SIZES)[number]) => {
      const el = exportRefs.current[index];
      if (!el) return null;

      el.style.left = "0px";
      el.style.opacity = "1";
      el.style.zIndex = "-1";

      const opts = { width: W, height: H, pixelRatio: 1, cacheBust: true };

      // Double-call trick: first warms fonts/images
      await toPng(el, opts);
      const dataUrl = await toPng(el, opts);

      el.style.left = "-9999px";
      el.style.opacity = "";
      el.style.zIndex = "";

      if (size.w === W && size.h === H) return dataUrl;

      return new Promise<string>((resolve) => {
        const img = new Image();
        img.onload = () => {
          const canvas = document.createElement("canvas");
          canvas.width = size.w;
          canvas.height = size.h;
          const ctx = canvas.getContext("2d")!;
          ctx.drawImage(img, 0, 0, size.w, size.h);
          resolve(canvas.toDataURL("image/png"));
        };
        img.src = dataUrl;
      });
    },
    []
  );

  const downloadDataUrl = (dataUrl: string, filename: string) => {
    const a = document.createElement("a");
    a.href = dataUrl;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  };

  const handleExportOne = useCallback(
    async (index: number) => {
      if (exporting) return;
      setExporting(true);
      const size = SIZES[sizeIndex];
      setStatus(`Exporting ${SLIDES[index].id}...`);
      const dataUrl = await exportSlide(index, size);
      if (dataUrl) {
        const num = String(index + 1).padStart(2, "0");
        downloadDataUrl(
          dataUrl,
          `${num}-${SLIDES[index].id}-${size.w}x${size.h}.png`
        );
      }
      setStatus("");
      setExporting(false);
    },
    [exporting, sizeIndex, exportSlide]
  );

  const handleExportAll = useCallback(async () => {
    if (exporting) return;
    setExporting(true);

    for (const size of SIZES) {
      for (let i = 0; i < SLIDES.length; i++) {
        setStatus(`Exporting ${SLIDES[i].id} at ${size.w}x${size.h}...`);
        const dataUrl = await exportSlide(i, size);
        if (dataUrl) {
          const num = String(i + 1).padStart(2, "0");
          downloadDataUrl(
            dataUrl,
            `${num}-${SLIDES[i].id}-${size.w}x${size.h}.png`
          );
        }
        await new Promise((r) => setTimeout(r, 300));
      }
    }

    setStatus("Done!");
    setTimeout(() => setStatus(""), 2000);
    setExporting(false);
  }, [exporting, exportSlide]);

  const handleExportAllCurrentSize = useCallback(async () => {
    if (exporting) return;
    setExporting(true);
    const size = SIZES[sizeIndex];

    for (let i = 0; i < SLIDES.length; i++) {
      setStatus(`Exporting ${SLIDES[i].id} at ${size.w}x${size.h}...`);
      const dataUrl = await exportSlide(i, size);
      if (dataUrl) {
        const num = String(i + 1).padStart(2, "0");
        downloadDataUrl(
          dataUrl,
          `${num}-${SLIDES[i].id}-${size.w}x${size.h}.png`
        );
      }
      await new Promise((r) => setTimeout(r, 300));
    }

    setStatus("Done!");
    setTimeout(() => setStatus(""), 2000);
    setExporting(false);
  }, [exporting, sizeIndex, exportSlide]);

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Toolbar */}
      <div className="sticky top-0 z-50 bg-white/80 backdrop-blur-lg border-b border-gray-200 px-6 py-4">
        <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <img src="/app-icon.png" alt="" className="w-8 h-8 rounded-lg" />
            <h1 className="text-lg font-bold text-gray-900">
              QuickSpend Screenshots
            </h1>
          </div>

          {/* Style tabs */}
          <div className="flex bg-gray-100 rounded-lg p-1 gap-1">
            {(Object.keys(STYLES) as StyleKey[]).map((key) => (
              <button
                key={key}
                onClick={() => setStyleKey(key)}
                className={`px-4 py-2 rounded-md text-sm font-medium transition-all ${
                  styleKey === key
                    ? "bg-white text-gray-900 shadow-sm"
                    : "text-gray-500 hover:text-gray-700"
                }`}
              >
                {STYLES[key].name}
              </button>
            ))}
          </div>

          {/* Size + export */}
          <div className="flex items-center gap-3">
            <select
              value={sizeIndex}
              onChange={(e) => setSizeIndex(Number(e.target.value))}
              className="bg-gray-100 border-none rounded-lg px-3 py-2 text-sm font-medium text-gray-700 cursor-pointer"
            >
              {SIZES.map((s, i) => (
                <option key={i} value={i}>
                  {s.label} ({s.w}x{s.h})
                </option>
              ))}
            </select>

            <button
              onClick={handleExportAllCurrentSize}
              disabled={exporting}
              className="bg-green-800 hover:bg-green-900 disabled:opacity-50 text-white px-4 py-2 rounded-lg text-sm font-semibold transition-colors"
            >
              Export {SIZES[sizeIndex].label}
            </button>

            <button
              onClick={handleExportAll}
              disabled={exporting}
              className="bg-gray-900 hover:bg-gray-800 disabled:opacity-50 text-white px-4 py-2 rounded-lg text-sm font-semibold transition-colors"
            >
              Export All Sizes
            </button>
          </div>
        </div>

        {status && (
          <div className="max-w-7xl mx-auto mt-2">
            <p className="text-sm text-green-700 font-medium">{status}</p>
          </div>
        )}
      </div>

      {/* Preview Grid */}
      <div className="max-w-7xl mx-auto px-6 py-8">
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
          {SLIDES.map((_, i) => (
            <PreviewCard
              key={`${styleKey}-${i}`}
              index={i}
              styleKey={styleKey}
              onExport={handleExportOne}
            />
          ))}
        </div>
      </div>

      {/* Offscreen export containers */}
      {SLIDES.map((_, i) => (
        <div
          key={`export-${styleKey}-${i}`}
          ref={(el) => {
            exportRefs.current[i] = el;
          }}
          style={{
            position: "absolute",
            left: "-9999px",
            top: 0,
            width: W,
            height: H,
            fontFamily: FONT,
          }}
        >
          <SlideContent index={i} styleKey={styleKey} />
        </div>
      ))}
    </div>
  );
}
