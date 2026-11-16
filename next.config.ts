import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Produces a self-contained server bundle in .next/standalone for Docker
  output: "standalone",
};

export default nextConfig;
