/**
 * DAR CAR design tokens — ported from website/src/lib/design/tokens.ts
 * (Flutter app SSOT: app_colors / app_spacing / app_radius).
 */

export const brand = {
  displayNameAr: "دار كار",
  displayNameEn: "DAR CAR",
  domain: "darcar.sa",
  appDomain: "darcar.app",
  tagline: "منصة سعودية رقمية للعقارات والسيارات",
} as const;

export const colors = {
  primary: "#7C3AED",
  primaryDark: "#5B21B6",
  primaryLight: "#EDE9FE",
  primaryLightLighter: "#F3EAFF",
  textPrimary: "#3F0071",
  textSecondary: "#6B21A8",
  onSurfaceMuted: "#64748B",
  white: "#FFFFFF",
  background: "#F9F6FF",
  success: "#22C063",
  warning: "#F59E0B",
  error: "#EF4444",
  info: "#3B82F6",
  border: "rgba(124, 58, 237, 0.12)",
  borderStrong: "rgba(124, 58, 237, 0.22)",
  shadow: "rgba(63, 0, 113, 0.10)",
} as const;

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
  page: 16,
  pageWide: 24,
  section: 24,
  sectionLarge: 32,
} as const;

export const radius = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  sheet: 24,
  pill: 999,
} as const;

export const motion = {
  fast: "160ms",
  base: "280ms",
  slow: "480ms",
  easeOut: "cubic-bezier(0.22, 1, 0.36, 1)",
  easeInOut: "cubic-bezier(0.65, 0, 0.35, 1)",
} as const;
