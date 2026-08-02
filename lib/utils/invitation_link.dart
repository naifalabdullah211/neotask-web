/// Builds the public one-time registration URL without inheriting the route
/// used by the account that created it (`/login`, nested paths, or queries).
String buildInvitationUrl(Uri currentLocation, String token) {
  final origin = '${currentLocation.scheme}://${currentLocation.authority}';
  return '$origin/?invite=${Uri.encodeQueryComponent(token.trim())}';
}
