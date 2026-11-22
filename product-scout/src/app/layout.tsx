import type { Metadata, Viewport } from "next";

import "./globals.css";

export const metadata: Metadata = {
  title: "Product Scout · 商品侦察台",
  description:
    "上传商品截图，提取品牌型号，检索公开渠道的标价、评分与评论片段，生成可核对的购买决策表。",
  applicationName: "Product Scout",
  robots: { index: false, follow: false }
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#F3EEE3"
};

export default function RootLayout({
  children
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
