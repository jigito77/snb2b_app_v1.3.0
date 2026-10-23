import '../../../../core/utils/json_utils.dart';

class Company {
  const Company({
    this.name = '',
    this.inn = '',
    this.kpp = '',
    this.ogrn = '',
    this.legalAddress = '',
    this.bankName = '',
    this.bik = '',
    this.account = '',
    this.corrAccount = '',
  });

  final String name;
  final String inn;
  final String kpp;
  final String ogrn;
  final String legalAddress;
  final String bankName;
  final String bik;
  final String account;
  final String corrAccount;

  bool get isEmpty => name.isEmpty && inn.isEmpty;

  factory Company.fromJson(Json j) => Company(
        name: j.str('name'),
        inn: j.str('inn'),
        kpp: j.str('kpp'),
        ogrn: j.str('ogrn'),
        legalAddress: j.str('legalAddress'),
        bankName: j.str('bankName'),
        bik: j.str('bik'),
        account: j.str('account'),
        corrAccount: j.str('corrAccount'),
      );

  Json toJson() => <String, dynamic>{
        'name': name,
        'inn': inn,
        'kpp': kpp,
        'ogrn': ogrn,
        'legalAddress': legalAddress,
        'bankName': bankName,
        'bik': bik,
        'account': account,
        'corrAccount': corrAccount,
      };
}

class ManagerInfo {
  const ManagerInfo({required this.name, required this.phone, this.email = ''});

  final String name;
  final String phone;
  final String email;

  factory ManagerInfo.fromJson(Json j) =>
      ManagerInfo(name: j.str('name'), phone: j.str('phone'), email: j.str('email'));

  Json toJson() => <String, dynamic>{'name': name, 'phone': phone, 'email': email};
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.company,
    this.isB2b = false,
    this.discountPercent = 0,
    this.manager,
    this.verificationStatus = '',
    this.canOrder = true,
    this.verificationMessage = '',
  });

  /// Статус верификации с backend: PENDING / VERIFIED / REJECTED / BLOCKED (меняется в админ-панели).
  final String verificationStatus;

  /// Может ли пользователь оформлять заказы (решает backend).
  final bool canOrder;
  final String verificationMessage;

  final String id;
  final String name;
  final String email;
  final String phone;
  final Company? company;

  /// Подтверждённый B2B-клиент: видит персональные и оптовые цены.
  final bool isB2b;
  final double discountPercent;
  final ManagerInfo? manager;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.substring(0, 1);
    final second = parts.length > 1 ? parts[1].substring(0, 1) : '';
    return (first + second).toUpperCase();
  }

  AppUser copyWith({String? name, String? phone, Company? company}) => AppUser(
        id: id,
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        company: company ?? this.company,
        isB2b: isB2b,
        discountPercent: discountPercent,
        manager: manager,
        verificationStatus: verificationStatus,
        canOrder: canOrder,
        verificationMessage: verificationMessage,
      );

  factory AppUser.fromJson(Json j) {
    final c = j.obj('company');
    final m = j.obj('manager');
    final v = j.obj('verification');
    return AppUser(
      id: j.str('id'),
      name: j.str('name'),
      email: j.str('email'),
      phone: j.str('phone'),
      company: c == null ? null : Company.fromJson(c),
      isB2b: j.flag('isB2b'),
      discountPercent: j.dbl('discountPercent'),
      manager: m == null ? null : ManagerInfo.fromJson(m),
      verificationStatus: v?.str('status') ?? j.str('verificationStatus'),
      canOrder: v == null ? true : v.flag('canOrder'),
      verificationMessage: v?.str('message') ?? '',
    );
  }

  Json toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'company': company?.toJson(),
        'isB2b': isB2b,
        'discountPercent': discountPercent,
        'manager': manager?.toJson(),
        'verification': <String, dynamic>{
          'status': verificationStatus,
          'canOrder': canOrder,
          'message': verificationMessage,
        },
      };
}

class RegisterData {
  const RegisterData({
    required this.name,
    required this.email,
    required this.password,
    this.phone = '',
    this.companyName = '',
    this.inn = '',
  });

  final String name;
  final String email;
  final String password;
  final String phone;
  final String companyName;
  final String inn;

  Json toJson() => <String, dynamic>{
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'companyName': companyName,
        'inn': inn,
      };
}

/// Способы входа. Сейчас в UI используется email + пароль, остальные уже
/// поддержаны на уровне репозитория и ждут соответствующих endpoint'ов backend.
sealed class AuthCredentials {
  const AuthCredentials();
}

class EmailPasswordCredentials extends AuthCredentials {
  const EmailPasswordCredentials(this.email, this.password);

  final String email;
  final String password;
}

class PhoneOtpCredentials extends AuthCredentials {
  const PhoneOtpCredentials(this.phone, this.code);

  final String phone;
  final String code;
}

class OAuthCredentials extends AuthCredentials {
  const OAuthCredentials(this.provider, this.token, {this.name = ''});

  /// google | apple (id-токен проверяет backend).
  final String provider;
  final String token;
  final String name;
}
