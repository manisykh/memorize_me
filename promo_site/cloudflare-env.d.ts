declare module "cloudflare:workers" {
  // The concrete binding types are injected by the Sites/Cloudflare runtime.
  // Keep the declaration broad so local TypeScript checks do not require a
  // standalone wrangler configuration file.
  export const env: Record<string, any>;
}
