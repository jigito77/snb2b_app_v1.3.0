import 'package:flutter/material.dart';

class CategoryIcons {
  CategoryIcons._();

  /// Иконка по идентификатору категории (родительской или дочерней).
  static IconData of(String categoryId) {
    final prefix = categoryId.split('-').first;
    switch (prefix) {
      case 'filters':
        return Icons.filter_alt_outlined;
      case 'engine':
        return Icons.settings_outlined;
      case 'fuel':
        return Icons.local_gas_station_outlined;
      case 'brakes':
        return Icons.album_outlined;
      case 'trans':
      case 'transmission':
        return Icons.sync_alt;
      case 'susp':
      case 'suspension':
        return Icons.speed_outlined;
      case 'el':
      case 'electric':
        return Icons.bolt_outlined;
      case 'cool':
      case 'cooling':
        return Icons.ac_unit;
      default:
        return Icons.build_outlined;
    }
  }
}
