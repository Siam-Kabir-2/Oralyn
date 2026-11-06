abstract final class ClerkConfig {
  // The existing Clerk development instance's publishable key is public.
  static const publishableKey = String.fromEnvironment(
    'CLERK_PUBLISHABLE_KEY',
    defaultValue:
        'pk_test_YmFsYW5jZWQtbWFtbWFsLTEyMDYuY2xlcmsuYWNjb3VudHMuZGV2JA',
  );
}
