enum AppLaunchMode { standard, unidesk }

AppLaunchMode resolveAppLaunchMode() {
  const raw = String.fromEnvironment('APP_LAUNCH_MODE', defaultValue: 'standard');
  switch (raw.trim().toLowerCase()) {
    case 'unidesk':
      return AppLaunchMode.unidesk;
    default:
      return AppLaunchMode.standard;
  }
}
