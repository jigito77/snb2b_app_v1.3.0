/// Контакты компании SNP Group (snb2b.ru). Меняются в одном месте.
class Contacts {
  Contacts._();

  static const String phoneArmenia = '+374 (98) 898-584';
  static const String phoneRussia = '+7 (901) 599-93-08';

  /// Номера для WhatsApp — только цифры, с кодом страны.
  static const String whatsappRussia = '79015999308';
  static const String whatsappArmenia = '37494003907';

  /// Telegram: основной аккаунт и канал «Всё для спецтехники».
  static const String telegramUser = 'snpgroop';
  static const String telegramChannel = 'snpgroupp';

  static const String instagramUrl = 'https://www.instagram.com/snp_group_';
  static const String facebookUrl = 'https://www.facebook.com/profile.php?id=61589939070840';

  static const String email = 'snp.groupp.llc@gmail.com';
  static const String website = 'https://snb2b.ru';

  static const String addressRussia = 'г. Москва, ул. Бутлерова, д. 17, помещение 129/5';
  static const String addressArmenia = 'г. Ванадзор, проспект Тиграна Меци, 20/1';

  static const String hoursRussia = 'Пн–Пт: 9:00–18:00 (МСК)';
  static const String hoursArmenia = 'Пн–Пт: 9:30–18:30';

  static Uri whatsappUri(String number, [String? text]) => Uri.https(
        'wa.me',
        '/$number',
        text == null || text.isEmpty ? null : <String, String>{'text': text},
      );

  static Uri telegramUri(String user) => Uri.https('t.me', '/$user');
}
