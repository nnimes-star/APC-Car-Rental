import type { Metadata } from "next";
import "./globals.css";
import "./live.css";

export const metadata: Metadata = {
  title: "APC Car Rental — Panabo & Davao City",
  description: "Check live vehicle availability and request a rental from APC Car Rental in Panabo and Davao City.",
  other: {
    "codex-preview": "development",
  },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
