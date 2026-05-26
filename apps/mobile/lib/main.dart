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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authProvider = AuthProvider();
  await authProvider.initialize();
  runApp(CreditNApp(authProvider: authProvider));
}

class CreditNApp extends StatelessWidget {
  final AuthProvider authProvider;
  const CreditNApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => MoimProvider()),
      ],
      child: Builder(
        builder: (context) {
          final router = _buildRouter(context.watch<AuthProvider>());
          return MaterialApp.router(
            title: 'Credit-N',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.dark(
                primary: const Color(0xFF6366F1),
                surface: const Color(0xFF1E293B),
              ),
              scaffoldBackgroundColor: const Color(0xFF0F172A),
              fontFamily: 'Pretendard',
            ),
            routerConfig: router,
          );
        },
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
          builder: (_, _) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          builder: (_, _) => const SignupScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/moims/create',
          builder: (_, _) => const CreateMoimScreen(),
        ),
        GoRoute(
          path: '/moims/:id',
          builder: (_, state) {
            final id = int.parse(state.pathParameters['id']!);
            return MoimDetailScreen(moimId: id);
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
