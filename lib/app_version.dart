// Build scripts pass the date version; keep the direct-build fallback in sync.
const appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '2026.10.25',
);
