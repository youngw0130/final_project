import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/moim_provider.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/create_moim_screen.dart';
import 'screens/moim_detail_screen.dart';
import 'screens/link_score_screen.dart';
import 'screens/qr_payment_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authProvider = AuthProvider();
  await authProvider.initialize();
  runApp(CreditNApp(authProvider: authProvider));
}

class CreditNApp extends StatefulWidget {
  final AuthProvider authProvider;
  const CreditNApp({super.key, required this.authProvider});

  @override
  State<CreditNApp> createState() => _CreditNAppState();
}

class _CreditNAppState extends State<CreditNApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter(widget.authProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.authProvider),
        ChangeNotifierProvider(create: (_) => MoimProvider()),
      ],
      child: MaterialApp.router(
        title: 'Credit-N',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.light(
            primary: const Color(0xFF0052FF),
            surface: Colors.white,
            background: const Color(0xFFF0F4FF),
          ),
          scaffoldBackgroundColor: const Color(0xFFF0F4FF),
          fontFamily: 'Pretendard',
          useMaterial3: true,
        ),
        routerConfig: _router,
        builder: kIsWeb
            ? (context, child) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: child!,
                  ),
                )
            : null,
      ),
    );
  }

  GoRouter _buildRouter(AuthProvider auth) {
    return GoRouter(
      initialLocation: auth.isLoggedIn ? '/dashboard' : '/login',
      redirect: (context, state) {
        final loggedIn = auth.isLoggedIn;
        final onAuth = state.matchedLocation == '/login' ||
            state.matchedLocation == '/signup';
        if (!loggedIn && !onAuth) return '/login';
        if (loggedIn && onAuth) return '/dashboard';
        return null;
      },
      refreshListenable: auth,
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          builder: (_, __) => const SignupScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/moims/create',
          builder: (_, __) => const CreateMoimScreen(),
        ),
        GoRoute(
          path: '/moims/:id',
          builder: (_, state) {
            final id = int.parse(state.pathParameters['id']!);
            return MoimDetailScreen(moimId: id);
          },
        ),
        GoRoute(
          path: '/moims/:id/pay',
          builder: (_, state) {
            final id = int.parse(state.pathParameters['id']!);
            return QrPaymentScreen(moimId: id);
          },
        ),
        GoRoute(
          path: '/link-score',
          builder: (_, __) => const LinkScoreScreen(),
        ),
      ],
    );
  }
}
