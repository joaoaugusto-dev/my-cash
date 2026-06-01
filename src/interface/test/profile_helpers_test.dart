import 'package:flutter_test/flutter_test.dart';
import 'package:my_cash/src/auth/profile_helpers.dart';

void main() {
  test('extractAvatarUrl returns null for empty metadata value', () {
    expect(extractAvatarUrl({'avatar_url': '   '}), isNull);
  });

  test('extractAvatarUrl returns url when present', () {
    expect(
      extractAvatarUrl({'avatar_url': 'https://cdn.example.com/avatar.png'}),
      'https://cdn.example.com/avatar.png',
    );
  });

  test('extractAvatarPath returns storage path when present', () {
    expect(
      extractAvatarPath({'avatar_path': 'user-id/avatar.jpg'}),
      'user-id/avatar.jpg',
    );
  });

  test('extractAvatarVersion returns null when absent', () {
    expect(extractAvatarVersion({'avatar_url': 'x'}), isNull);
  });

  test('normalizeGoogleAvatarUrl enforces 256 size in google avatar urls', () {
    final url = 'https://lh3.googleusercontent.com/a/ACg8oc=s96-c';
    expect(
      normalizeGoogleAvatarUrl(url),
      'https://lh3.googleusercontent.com/a/ACg8oc=s256-c',
    );
  });

  test('buildAvatarCacheAwareUrl appends version query once', () {
    final url = buildAvatarCacheAwareUrl(
      'https://cdn.example.com/avatar.jpg',
      '1234',
    );
    expect(url, 'https://cdn.example.com/avatar.jpg?v=1234');
  });

  test('initialsFromProfile uses first two words of full name', () {
    expect(
      initialsFromProfile(fullName: 'Maria da Silva', email: 'maria@email.com'),
      'MD',
    );
  });

  test('initialsFromProfile falls back to email first letter', () {
    expect(initialsFromProfile(fullName: '', email: 'joao@email.com'), 'J');
  });
}
