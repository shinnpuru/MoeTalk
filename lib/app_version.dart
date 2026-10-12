// Build scripts pass the package version; keep the direct-build fallback in sync.
const appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.4.0+2026101200',
);
