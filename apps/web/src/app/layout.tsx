import type { Metadata } from "next";
import type { ReactNode } from "react";
import { Web3Provider } from "@/components/web3-provider";
import "./globals.css";

export const metadata: Metadata = {
  title: "DUREQO — Financial Continuity Infrastructure",
  description: "Pre-authorize what must survive without pre-authorizing unrestricted access.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body><Web3Provider>{children}</Web3Provider></body>
    </html>
  );
}
