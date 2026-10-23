// СГЕНЕРИРОВАНО tool/i18n/gen.py — не править вручную.
// ignore_for_file: prefer_single_quotes, lines_longer_than_80_chars

class _Rule {
  _Rule(String pattern, this.templates) : regex = RegExp(pattern);

  final RegExp regex;
  final Map<String, String> templates;
}

final List<_Rule> _rules = <_Rule>[
  _Rule(r'^От (\d+) до (\d+) шт\.$', <String, String>{'en': 'From {1} to {2} pcs', 'hy': 'Սկսած {1}-ից մինչև {2} հատ', 'ka': '{1}-დან {2} ც.-მდე'}),
  _Rule(r'^Запрос из приложения (.+)$', <String, String>{'en': 'Request from the {1} app', 'hy': 'Հարցում {1} հավելվածից', 'ka': 'მოთხოვნა {1} აპლიკაციიდან'}),
  _Rule(r'^В наличии: (.+)$', <String, String>{'en': 'In stock: {1}', 'hy': 'Առկա է՝ {1}', 'ka': 'მარაგშია: {1}'}),
  _Rule(r'^В наличии \((.+)\)$', <String, String>{'en': 'In stock ({1})', 'hy': 'Առկա է ({1})', 'ka': 'მარაგშია ({1})'}),
  _Rule(r'^Арт\. (.+)$', <String, String>{'en': 'Art. {1}', 'hy': 'Արտ. {1}', 'ka': 'არტ. {1}'}),
  _Rule(r'^под заказ (.+)$', <String, String>{'en': 'made to order, {1}', 'hy': 'պատվերով՝ {1}', 'ka': 'შეკვეთით, {1}'}),
  _Rule(r'^Найдено: (.+)$', <String, String>{'en': 'Found: {1}', 'hy': 'Գտնվել է՝ {1}', 'ka': 'ნაპოვნია: {1}'}),
  _Rule(r'^от ([\d ,]+ ?₽)\s*$', <String, String>{'en': 'from {1}', 'hy': 'սկսած {1}', 'ka': '{1}-დან'}),
  _Rule(r'^до ([\d ,]+ ?₽)\s*$', <String, String>{'en': 'up to {1}', 'hy': 'մինչև {1}', 'ka': '{1}-მდე'}),
  _Rule(r'^от (\d+) шт\.$', <String, String>{'en': 'from {1} pcs', 'hy': '{1} հատից', 'ka': '{1} ც.-დან'}),
  _Rule(r'^Все в категории «(.+)»$', <String, String>{'en': 'All in “{1}”', 'hy': 'Ամբողջը «{1}» կատեգորիայում', 'ka': 'ყველა კატეგორიაში „{1}“'}),
  _Rule(r'^Показать все \((\d+)\)$', <String, String>{'en': 'Show all ({1})', 'hy': 'Ցույց տալ բոլորը ({1})', 'ka': 'ყველას ჩვენება ({1})'}),
  _Rule(r'^Показать (\d+ .+)$', <String, String>{'en': 'Show {1}', 'hy': 'Ցույց տալ {1}', 'ka': 'ჩვენება: {1}'}),
  _Rule(r'^Если аккаунт с адресом (.+) существует, мы отправили на него ссылку для смены пароля\.$', <String, String>{'en': 'If an account with the address {1} exists, we have sent a password reset link to it.', 'hy': 'Եթե {1} հասցեով հաշիվ գոյություն ունի, մենք դրան ուղարկել ենք գաղտնաբառը փոխելու հղում։', 'ka': 'თუ ანგარიში მისამართით {1} არსებობს, მასზე გავაგზავნეთ პაროლის შეცვლის ბმული.'}),
  _Rule(r'^Добавлено позиций: (\d+)\. Недоступно: (\d+)$', <String, String>{'en': 'Items added: {1}. Unavailable: {2}', 'hy': 'Ավելացվել է դիրքեր՝ {1}։ Անհասանելի՝ {2}', 'ka': 'დამატებულია პოზიცია: {1}. მიუწვდომელია: {2}'}),
  _Rule(r'^Заказ №(.+) успешно создан$', <String, String>{'en': 'Order №{1} created successfully', 'hy': 'Պատվեր №{1}-ը հաջողությամբ ստեղծվել է', 'ka': 'შეკვეთა №{1} წარმატებით შეიქმნა'}),
  _Rule(r'^Заказ №(.+) принят$', <String, String>{'en': 'Order №{1} received', 'hy': 'Պատվեր №{1}-ն ընդունված է', 'ka': 'შეკვეთა №{1} მიღებულია'}),
  _Rule(r'^Заказ №(.+) отправлен$', <String, String>{'en': 'Order №{1} shipped', 'hy': 'Պատվեր №{1}-ն ուղարկված է', 'ka': 'შეკვეთა №{1} გაგზავნილია'}),
  _Rule(r'^Заказ №(.+) подтверждён$', <String, String>{'en': 'Order №{1} confirmed', 'hy': 'Պատվեր №{1}-ը հաստատված է', 'ka': 'შეკვეთა №{1} დადასტურებულია'}),
  _Rule(r'^Заказ №(.+)$', <String, String>{'en': 'Order №{1}', 'hy': 'Պատվեր №{1}', 'ka': 'შეკვეთა №{1}'}),
  _Rule(r'^(.+) и ещё (\d+)$', <String, String>{'en': '{1} and {2} more', 'hy': '{1} և ևս {2}', 'ka': '{1} და კიდევ {2}'}),
  _Rule(r'^Подтвердить заказ · (.+)$', <String, String>{'en': 'Confirm order · {1}', 'hy': 'Հաստատել պատվերը · {1}', 'ka': 'შეკვეთის დადასტურება · {1}'}),
  _Rule(r'^Скидка ([\d.,]+)%$', <String, String>{'en': 'Discount {1}%', 'hy': 'Զեղչ {1}%', 'ka': 'ფასდაკლება {1}%'}),
  _Rule(r'^Сайт (.+)$', <String, String>{'en': 'Website {1}', 'hy': 'Կայք {1}', 'ka': 'ვებსაიტი {1}'}),
  _Rule(r'^Сравнение · (\d+)$', <String, String>{'en': 'Compare · {1}', 'hy': 'Համեմատություն · {1}', 'ka': 'შედარება · {1}'}),
  _Rule(r'^Доступно только (.+)$', <String, String>{'en': 'Only {1} available', 'hy': 'Հասանելի է միայն {1}', 'ka': 'ხელმისაწვდომია მხოლოდ {1}'}),
  _Rule(r'^Мин\. заказ: (.+)$', <String, String>{'en': 'Min. order: {1}', 'hy': 'Նվազ. պատվեր՝ {1}', 'ka': 'მინ. შეკვეთა: {1}'}),
  _Rule(r'^Добавлено в корзину: (\d+) шт\.$', <String, String>{'en': 'Added to cart: {1} pcs', 'hy': 'Ավելացվեց զամբյուղ՝ {1} հատ', 'ka': 'დაემატა კალათაში: {1} ც.'}),
  _Rule(r'^Скопировано: (.+)$', <String, String>{'en': 'Copied: {1}', 'hy': 'Պատճենվեց՝ {1}', 'ka': 'დაკოპირდა: {1}'}),
  _Rule(r'^Производитель: (.+)$', <String, String>{'en': 'Manufacturer: {1}', 'hy': 'Արտադրող՝ {1}', 'ka': 'მწარმოებელი: {1}'}),
  _Rule(r'^Минимальное количество для заказа: (.+)$', <String, String>{'en': 'Minimum order quantity: {1}', 'hy': 'Պատվերի նվազագույն քանակ՝ {1}', 'ka': 'შეკვეთის მინიმალური რაოდენობა: {1}'}),
  _Rule(r'^Склад: (.+)$', <String, String>{'en': 'Warehouse: {1}', 'hy': 'Պահեստ՝ {1}', 'ka': 'საწყობი: {1}'}),
  _Rule(r'^В корзину · (.+)$', <String, String>{'en': 'Add to cart · {1}', 'hy': 'Զամբյուղ · {1}', 'ka': 'კალათაში · {1}'}),
  _Rule(r'^КП-(\d+)$', <String, String>{'en': 'RFQ-{1}', 'hy': 'ԱԱ-{1}', 'ka': 'კშ-{1}'}),
  _Rule(r'^(\d+) шт\.$', <String, String>{'en': '{1} pcs', 'hy': '{1} հատ', 'ka': '{1} ც.'}),
  _Rule(r'^(\d+) кг$', <String, String>{'en': '{1} kg', 'hy': '{1} կգ', 'ka': '{1} კგ'}),
  _Rule(r'^(\d+) (?:месяц|месяца|месяцев)$', <String, String>{'en': '{1} months', 'hy': '{1} ամիս', 'ka': '{1} თვე'}),
  _Rule(r'^(.+), с (\d+) г\.$', <String, String>{'en': '{1}, from {2}', 'hy': '{1}, սկսած {2} թ.', 'ka': '{1}, {2} წლიდან'}),
  _Rule(r'^(.+) для техники (.+)\. Подбор по артикулу и OEM-номеру, проверка комплектности перед отгрузкой\. Рассчитан на эксплуатацию в тяжёлых условиях\. Демонстрационное описание\.$', <String, String>{'en': '{1} for {2} equipment. Selection by part and OEM number, completeness check before shipping. Designed for heavy-duty operation. Demo description.', 'hy': '{1}՝ {2} տեխնիկայի համար։ Ընտրություն արտիկուլով և OEM համարով, համալրվածության ստուգում առաքումից առաջ։ Նախատեսված է ծանր պայմաններում շահագործման համար։ Դեմո նկարագրություն։', 'ka': '{1} {2} ტექნიკისთვის. შერჩევა არტიკულითა და OEM ნომრით, კომპლექტაციის შემოწმება გაგზავნამდე. განკუთვნილია მძიმე პირობებში ექსპლუატაციისთვის. დემო აღწერა.'}),
];

/// Переводит динамическую строку по шаблонам. null — если ни одно правило не подошло.
String? translateByRules(String ru, String lang, String Function(String) tr) {
  for (final rule in _rules) {
    final m = rule.regex.firstMatch(ru);
    if (m == null) continue;
    var out = rule.templates[lang];
    if (out == null) return null;
    for (var i = 1; i <= m.groupCount; i++) {
      out = out!.replaceAll('{$i}', tr(m.group(i) ?? ''));
    }
    return out;
  }
  return null;
}
