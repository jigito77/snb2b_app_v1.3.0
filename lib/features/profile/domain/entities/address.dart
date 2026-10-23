import '../../../../core/utils/json_utils.dart';

class Address {
  const Address({
    required this.id,
    required this.title,
    required this.city,
    required this.street,
    this.comment = '',
    this.isDefault = false,
  });

  final String id;
  final String title;
  final String city;
  final String street;
  final String comment;
  final bool isDefault;

  String get fullAddress => street.isEmpty ? city : '$city, $street';

  factory Address.fromJson(Json j) => Address(
        id: j.str('id'),
        title: j.str('title'),
        city: j.str('city'),
        street: j.str('street'),
        comment: j.str('comment'),
        isDefault: j.flag('isDefault'),
      );

  Json toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'city': city,
        'street': street,
        'comment': comment,
        'isDefault': isDefault,
      };
}
