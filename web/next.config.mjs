/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  // Im Produktionsbetrieb routet Caddy /api -> Backend; dieser Rewrite dient
  // der lokalen Entwicklung ohne Proxy.
  async rewrites() {
    const backend = process.env.INTERNAL_API_URL ?? 'http://localhost:3001';
    return [{ source: '/api/:path*', destination: `${backend}/:path*` }];
  },
};

export default nextConfig;
