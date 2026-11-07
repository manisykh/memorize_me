/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "export",
  trailingSlash: true,
  images: {
    unoptimized: true,
  },
  typescript: {
    tsconfigPath: "tsconfig.netlify.json",
  },
};

export default nextConfig;
