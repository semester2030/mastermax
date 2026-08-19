import type { Metadata } from "next";
import { IBM_Plex_Sans_Arabic, Outfit } from "next/font/google";
import { brand } from "@/lib/design/tokens";
import "./globals.css";

export const dynamic = "force-dynamic";

const arabic = IBM_Plex_Sans_Arabic({
  variable: "--font-arabic",
  subsets: ["arabic"],
  weight: ["300", "400", "500", "600", "700"],
  display: "swap",
});

const display = Outfit({
  variable: "--font-display",
  subsets: ["latin"],
  weight: ["500", "600", "700"],
  display: "swap",
});

const appName =
  process.env.NEXT_PUBLIC_APP_NAME?.trim() ||
  `${brand.displayNameAr} — مقدم الخدمة`;

export const metadata: Metadata = {
  title: {
    default: appName,
    template: `%s | ${brand.displayNameAr}`,
  },
  description: "لوحة مقدم الخدمة — Wave1 (داخلي)",
  applicationName: appName,
  robots: { index: false, follow: false },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="ar"
      dir="rtl"
      className={`${arabic.variable} ${display.variable} h-full antialiased`}
    >
      <body className="flex min-h-full flex-col font-sans">{children}</body>
    </html>
  );
}
