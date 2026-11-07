const supportEmail = process.env.NEXT_PUBLIC_SUPPORT_EMAIL?.trim() ?? "";
const configuredSiteUrl = process.env.NEXT_PUBLIC_SITE_URL?.trim() ?? "";
const feedbackAdminPassword = process.env.FEEDBACK_ADMIN_PASSWORD?.trim() ?? "";
const feedbackSessionSecret = process.env.FEEDBACK_SESSION_SECRET?.trim() ?? "";

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

if (!emailPattern.test(supportEmail)) {
  console.error(
    "[release-check] NEXT_PUBLIC_SUPPORT_EMAIL must be a valid public support email.",
  );
  process.exit(1);
}

if (configuredSiteUrl) {
  let url;
  try {
    url = new URL(configuredSiteUrl);
  } catch {
    console.error(
      "[release-check] NEXT_PUBLIC_SITE_URL must be a valid absolute URL.",
    );
    process.exit(1);
  }

  if (url.protocol !== "https:") {
    console.error(
      "[release-check] NEXT_PUBLIC_SITE_URL must use HTTPS for production.",
    );
    process.exit(1);
  }
}

if (feedbackAdminPassword.length < 10) {
  console.error(
    "[release-check] FEEDBACK_ADMIN_PASSWORD must contain at least 10 characters.",
  );
  process.exit(1);
}

if (feedbackSessionSecret.length < 32) {
  console.error(
    "[release-check] FEEDBACK_SESSION_SECRET must contain at least 32 characters.",
  );
  process.exit(1);
}

console.log("[release-check] Netlify public configuration is valid.");
