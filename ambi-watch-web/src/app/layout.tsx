import type { Metadata } from "next";
import { Geist, Geist_Mono, Inter, Marcellus } from "next/font/google";
import { SiteHeader } from "@/components/site/site-header";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
});

const marcellus = Marcellus({
  variable: "--font-marcellus",
  subsets: ["latin"],
  weight: "400",
});

export const metadata: Metadata = {
  title: {
    default: "ambi watch",
    template: "%s · ambi watch",
  },
  description: "ambi watch design system and screens.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} ${inter.variable} ${marcellus.variable} antialiased`}
    >
      <body className="min-h-dvh bg-canvas-soft text-ink">
        <SiteHeader />
        {children}
      </body>
    </html>
  );
}
