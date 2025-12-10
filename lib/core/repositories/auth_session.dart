/// Simple in-memory store for the current authentication token.
///
/// This token is used by API clients (e.g. `CreatureApi`) to authenticate
/// requests via the `Authorization: Bearer <token>` header.
class AuthSession {
  static String? _token;

  static String? get token => _token;

  static void setToken(String? value) {
    _token = value;
  }

  static void clear() {
    _token = null;
  }
}


