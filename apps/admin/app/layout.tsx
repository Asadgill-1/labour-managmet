import type { Metadata, Viewport } from "next";
import { Roboto } from "next/font/google";
import "./globals.css";

const roboto = Roboto({ subsets: ["latin"], weight: ["400", "500", "700"], variable: "--font-roboto", display: "swap" });

export const metadata: Metadata = {
  title: "Labour app, malik ka dashboard",
  description: "Platform ke malik ka dashboard: accounts, slips, plans aur audit log.",
  robots: { index: false, follow: false },
};
export const viewport: Viewport = { width: "device-width", initialScale: 1, themeColor: "#0B2648" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={roboto.variable}>
      <body>
        <noscript><p style={{ padding: 16 }}>Ye dashboard JavaScript ke baghair nahin chalta.</p></noscript>
        {children}
      </body>
    </html>
  );
}
