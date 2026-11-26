import type { NextConfig } from "next";

// A static site: it holds nothing but the public URL and key, and can be hosted anywhere (D-081). Pages that need an
// id take it in the query string.
const config: NextConfig = { output: "export", trailingSlash: true, images: { unoptimized: true } };

export default config;
