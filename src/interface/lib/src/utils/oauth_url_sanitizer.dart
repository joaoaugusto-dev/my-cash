import 'package:my_cash/src/utils/oauth_url_sanitizer_stub.dart'
    if (dart.library.html) 'package:my_cash/src/utils/oauth_url_sanitizer_web.dart';

void sanitizeOAuthUrl() {
  sanitizeOAuthUrlImpl();
}
