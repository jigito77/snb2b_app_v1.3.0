import '../../../core/utils/formatters.dart';
import 'entities/order.dart';

/// Текст заказа для отправки менеджеру в WhatsApp / Telegram.
/// [maxItems] ограничивает список позиций (для длинных заказов в ссылке WhatsApp).
String buildOrderMessage(Order o, {int? maxItems}) {
  final b = StringBuffer()
    ..writeln('Новый заказ №${o.number} (приложение SNP)')
    ..writeln();
  final items = maxItems == null || o.items.length <= maxItems ? o.items : o.items.take(maxItems).toList();
  for (var i = 0; i < items.length; i++) {
    final it = items[i];
    b.writeln('${i + 1}. ${it.name}');
    b.writeln('   Арт. ${it.article} — ${it.qty} шт. × ${Fmt.price(it.price, currency: 'RUB')} = ${Fmt.price(it.total, currency: 'RUB')}');
  }
  if (items.length < o.items.length) {
    b.writeln('… и ещё ${o.items.length - items.length} поз. (полный список — в приложении)');
  }
  b
    ..writeln()
    ..writeln('Итого: ${Fmt.price(o.total, currency: 'RUB')} (${o.units} шт.)')
    ..writeln()
    ..writeln('Контакт: ${o.contactName}');
  if (o.company.isNotEmpty) b.writeln('Компания: ${o.company}');
  b.writeln('Телефон: ${o.phone}');
  if (o.email.isNotEmpty) b.writeln('Email: ${o.email}');
  b.writeln('Доставка: ${CheckoutOptions.deliveryTitle(o.deliveryMethod)}');
  if (o.address.isNotEmpty) b.writeln('Адрес: ${o.address}');
  b.writeln('Оплата: ${CheckoutOptions.paymentTitle(o.paymentMethod)}');
  if (o.comment.isNotEmpty) b.writeln('Комментарий: ${o.comment}');
  return b.toString().trimRight();
}
