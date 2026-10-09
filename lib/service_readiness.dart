class ServiceReadiness {
  const ServiceReadiness._();

  static Uri? httpsUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  static bool ready({
    required bool accepted,
    required String privacyUrl,
    required String supportUrl,
    required String accountDeletionUrl,
  }) =>
      accepted &&
      httpsUrl(privacyUrl) != null &&
      httpsUrl(supportUrl) != null &&
      httpsUrl(accountDeletionUrl) != null;

  // Set only after the privacy, support, deletion, report/block and live
  // service acceptance records have been reviewed for this exact build.
  static bool get liveServiceAccepted => ready(
    accepted: const bool.fromEnvironment('LIVE_SERVICE_ACCEPTED'),
    privacyUrl: const String.fromEnvironment('PRIVACY_POLICY_URL'),
    supportUrl: const String.fromEnvironment('SUPPORT_URL'),
    accountDeletionUrl: const String.fromEnvironment('ACCOUNT_DELETION_URL'),
  );
}
