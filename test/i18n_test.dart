
import 'package:test/test.dart';
import '../lib/i18n.dart';

void main() {
  group('I18n', () {
    test('default language is zh', () {
      expect(I18n.locale, 'zh');
    });

    test('can switch language', () {
      I18n.locale = 'en';
      expect(I18n.locale, 'en');
    });

    test('translates correctly', () {
      I18n.locale = 'zh';
      expect(I18n.t('welcome'), '欢迎使用');
      I18n.locale = 'en';
      expect(I18n.t('welcome'), 'Welcome');
    });

    test('returns key if translation missing', () {
      I18n.locale = 'en';
      expect(I18n.t('missing_key'), 'missing_key');
    });
  });
}
