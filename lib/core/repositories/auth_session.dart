/// Simple in-memory store for the current authentication tokens.
///
/// The access token is used by API clients (e.g. `CreatureApi`) to authenticate
/// requests via the `Authorization: Bearer <token>` header, while the refresh
/// token is used when logging out.
class AuthSession {
  static String? _accessToken;
  static String? _refreshToken;

  static String? get token => _accessToken;
  static String? get refreshToken => _refreshToken;

  static void setToken(String? value) {
    _accessToken = value;
  }

  static void setTokens({
    required String accessToken,
    String? refreshToken,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  static void clear() {
    _accessToken = null;
    _refreshToken = null;
  }
}


