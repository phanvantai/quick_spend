import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "QuickSpend — App Store Screenshots",
  description: "Screenshot generator for QuickSpend",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        style={{
          fontFamily:
            '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", system-ui, sans-serif',
        }}
        className="antialiased"
      >
        {children}
      </body>
    </html>
  );
}
