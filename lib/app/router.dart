import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/cart/presentation/pages/cart_page.dart';
import '../features/catalog/presentation/pages/catalog_page.dart';
import '../features/catalog/presentation/pages/product_list_page.dart';
import '../features/comparison/presentation/pages/comparison_page.dart';
import '../features/favorites/presentation/pages/favorites_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/home/presentation/pages/news_pages.dart';
import '../features/info/presentation/pages/info_page.dart';
import '../features/notifications/presentation/pages/notifications_page.dart';
import '../features/orders/presentation/pages/checkout_page.dart';
import '../features/orders/presentation/pages/order_detail_page.dart';
import '../features/orders/presentation/pages/order_success_page.dart';
import '../features/orders/presentation/pages/orders_page.dart';
import '../features/orders/presentation/pages/quote_page.dart';
import '../features/product/presentation/pages/product_page.dart';
import '../features/profile/presentation/pages/addresses_page.dart';
import '../features/profile/presentation/pages/profile_data_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/profile/presentation/pages/requisites_page.dart';
import '../features/profile/presentation/pages/settings_page.dart';
import '../features/search/presentation/pages/search_page.dart';
import '../features/support/presentation/support_chat_page.dart';
import 'main_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Маршруты, доступные только авторизованному пользователю.
const List<String> _protectedPrefixes = <String>[
  '/checkout',
  '/orders',
  '/profile/data',
  '/profile/addresses',
  '/profile/requisites',
  '/notifications',
];

bool _isProtected(String path) {
  for (final p in _protectedPrefixes) {
    if (path == p || path.startsWith('$p/')) return true;
  }
  return false;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    if (previous?.status != next.status) refresh.value++;
  });

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.uri.path;
      if (path == '/') return '/home';
      final auth = ref.read(authControllerProvider);
      if (_isProtected(path) && !auth.isAuthenticated) {
        return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      return null;
    },
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(path: '/home', builder: (context, state) => const HomePage()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(path: '/catalog', builder: (context, state) => const CatalogPage()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(path: '/favorites', builder: (context, state) => const FavoritesPage()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(path: '/cart', builder: (context, state) => const CartPage()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
          ]),
        ],
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => SearchPage(initialQuery: state.uri.queryParameters['q'] ?? ''),
      ),
      GoRoute(
        path: '/products',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ProductListPage(
          initialFilter: filterFromQuery(state.uri.queryParameters),
          title: state.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: '/product/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ProductPage(productId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/compare',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ComparisonPage(),
      ),
      GoRoute(
        path: '/checkout',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CheckoutPage(),
      ),
      GoRoute(
        path: '/checkout/success',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => OrderSuccessPage(
          number: state.uri.queryParameters['number'] ?? '',
          orderId: state.uri.queryParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/orders',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OrdersPage(),
      ),
      GoRoute(
        path: '/orders/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => OrderDetailPage(orderId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/quote',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => QuotePage(
          productId: state.uri.queryParameters['productId'],
          qty: int.tryParse(state.uri.queryParameters['qty'] ?? '') ?? 1,
        ),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => LoginPage(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/register',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => RegisterPage(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/forgot-password',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/profile/data',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ProfileDataPage(),
      ),
      GoRoute(
        path: '/profile/requisites',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RequisitesPage(),
      ),
      GoRoute(
        path: '/profile/addresses',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AddressesPage(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/support/chat',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SupportChatPage(),
      ),
      GoRoute(
        path: '/news',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NewsListPage(),
      ),
      GoRoute(
        path: '/news/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => NewsDetailPage(newsId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/info/:slug',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => InfoPage(slug: state.pathParameters['slug'] ?? ''),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
