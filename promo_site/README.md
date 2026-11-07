# Memorize Me promotional site

The promotional page combines the real app screenshots in `public/media` with
the colored-pencil onboarding artwork.

## Quick preview

Open `index.html` directly in a browser. This static preview does not require a
Flutter or Node build.

## Sites source

The deployable page source is kept in `app/page.tsx`, `app/layout.tsx`, and
`app/globals.css`. The Sites/Vinext toolchain requires Node.js 22.13 or newer.

## Release configuration

Before deploying, copy `.env.example` to the deployment environment and set
`NEXT_PUBLIC_SUPPORT_EMAIL` to a public support address monitored by the app
operator. This address is shown on `/account-deletion` so users who cannot open
the app can request account deletion.

The public deployment must keep both of these routes available:

- `/privacy`
- `/account-deletion`

These URLs are also linked from the Android app's **개인정보 및 계정 삭제**
screen. After deployment, verify both routes on the production domain and use
the same URLs in the Google Play Console's privacy policy and account deletion
fields.

## Netlify deployment

The repository root contains `netlify.toml`. When this repository is imported,
Netlify uses `promo_site` as the base directory, runs `npm run build:netlify`,
and publishes the static `out` directory.

Before the first production deploy, add this environment variable in
**Project configuration > Environment variables**:

```text
NEXT_PUBLIC_SUPPORT_EMAIL=your-public-support@example.com
FEEDBACK_ADMIN_PASSWORD=your-private-admin-password
FEEDBACK_SESSION_SECRET=a-random-secret-at-least-32-characters
```

The tester board is deployed as a Netlify Function at `/api/feedback` and uses
the site-wide `memorize-feedback` Netlify Blobs store. Deploy the repository
through Git or the Netlify CLI; a static drag-and-drop of `index.html` does not
include the function. After deployment, create a test post, edit it with its
post password, add an administrator reply, and confirm that the post is still
present after a new deploy.

Netlify automatically provides the production site URL. If a custom domain is
used, you can additionally set `NEXT_PUBLIC_SITE_URL` to that HTTPS origin and
redeploy so social sharing metadata uses the custom domain.

After deployment, confirm that `/privacy/` and `/account-deletion/` both return
HTTP 200 in a private browser window. The environment variable is embedded at
build time, so changing it requires a new deploy.

The Netlify build intentionally fails when `NEXT_PUBLIC_SUPPORT_EMAIL` is
missing or malformed. This prevents publishing an account-deletion page that
does not provide a working external request channel. If
`NEXT_PUBLIC_SITE_URL` is set, it must be an absolute HTTPS URL.
