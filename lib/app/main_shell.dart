import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/app_text.dart';
import '../core/network/network_status.dart';
import '../core/theme/app_colors.dart';
import '../features/cart/presentation/providers/cart_provider.dart';
import '../shared/state/product_collections.dart';
import '../shared/widgets/common.dart';

/// Каркас с нижней навигацией: Главная, Каталог, Избранное, Корзина, Профиль.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  Widget _badged(int count, Widget icon) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: AppColors.accent,
      textColor: AppColors.onAccent,
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartProvider.select((l) => l.length));
    final favCount = ref.watch(favoritesProvider.select((l) => l.length));
    final online = ref.watch(networkStatusProvider);
    final index = navigationShell.currentIndex;

    Widget body = navigationShell;
    if (!online) {
      body = Column(
        children: <Widget>[
          Material(
            color: AppColors.warningSoft,
            child: const SafeArea(bottom: false, child: OfflineBanner()),
          ),
          Expanded(
            child: MediaQuery.removePadding(context: context, removeTop: true, child: navigationShell),
          ),
        ],
      );
    }

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && index != 0) navigationShell.goBranch(0);
      },
      child: Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) =>
              navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
          destinations: <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: tr('Главная'),
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: tr('Каталог'),
            ),
            NavigationDestination(
              icon: _badged(favCount, const Icon(Icons.favorite_border)),
              selectedIcon: _badged(favCount, const Icon(Icons.favorite)),
              label: tr('Избранное'),
            ),
            NavigationDestination(
              icon: _badged(cartCount, const Icon(Icons.shopping_cart_outlined)),
              selectedIcon: _badged(cartCount, const Icon(Icons.shopping_cart)),
              label: tr('Корзина'),
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: tr('Профиль'),
            ),
          ],
        ),
      ),
    );
  }
}
