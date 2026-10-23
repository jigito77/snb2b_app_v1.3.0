import 'package:flutter/widgets.dart' as w;

import 'l10n.dart';

export 'l10n.dart' show tr, L10n, AppLanguage;

/// Замена стандартного `Text`: переводит русский исходный текст на выбранный
/// язык. Для остальных строк (артикулы, имена, числа) ведёт себя как обычный Text.
class Text extends w.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
  });

  final String data;
  final w.TextStyle? style;
  final w.StrutStyle? strutStyle;
  final w.TextAlign? textAlign;
  final w.TextDirection? textDirection;
  final w.Locale? locale;
  final bool? softWrap;
  final w.TextOverflow? overflow;
  final w.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final w.TextWidthBasis? textWidthBasis;
  final w.TextHeightBehavior? textHeightBehavior;

  @override
  w.Widget build(w.BuildContext context) {
    final code = w.Localizations.maybeLocaleOf(context)?.languageCode ?? L10n.lang;
    return w.Text(
      L10n.tr(data, code),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null ? null : L10n.tr(semanticsLabel!, code),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
    );
  }
}
