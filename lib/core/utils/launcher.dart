import 'package:url_launcher/url_launcher.dart';

import '../constants/contacts.dart';

Future<bool> openUri(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<bool> callPhone(String phone) =>
    openUri(Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), '')));

Future<bool> sendMail(String email, {String? subject}) => openUri(Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: subject == null ? null : <String, String>{'subject': subject},
    ));

Future<bool> openWebsite(String url) => openUri(Uri.parse(url));

/// WhatsApp-чат с отделом продаж (по умолчанию — российский номер).
Future<bool> openWhatsApp({String? text, String number = Contacts.whatsappRussia}) =>
    openUri(Contacts.whatsappUri(number, text));

Future<bool> openTelegram({String user = Contacts.telegramUser}) => openUri(Contacts.telegramUri(user));
