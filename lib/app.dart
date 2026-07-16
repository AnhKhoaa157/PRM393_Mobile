part of 'main.dart';

class ParkingApp extends StatefulWidget {
  const ParkingApp({super.key});

  @override
  State<ParkingApp> createState() => _ParkingAppState();
}

class _ParkingAppState extends State<ParkingApp> with WidgetsBindingObserver {
  final session = SessionController(ApiClient());
  String? resetToken;

  @override
  void initState() {
    super.initState();
    resetToken = _resetTokenFromLaunchRoute();
    WidgetsBinding.instance.addObserver(this);
    session.addListener(_refresh);
    session.restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.removeListener(_refresh);
    session.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  String? _resetTokenFromLaunchRoute() {
    final routes = [
      WidgetsBinding.instance.platformDispatcher.defaultRouteName,
      Uri.base.toString(),
    ];
    for (final route in routes) {
      final token = _resetTokenFromRoute(route);
      if (token != null) return token;
    }
    return null;
  }

  String? _resetTokenFromRoute(String route) {
    final uri = Uri.tryParse(route);
    if (uri == null) return null;
    final isResetRoute =
        (uri.scheme == 'pbms' && uri.host == 'reset-password') ||
            uri.path.endsWith('/reset-password');
    final token = uri.queryParameters['token']?.trim();
    return isResetRoute && token != null && token.isNotEmpty ? token : null;
  }

  @override
  Future<bool> didPushRoute(String route) async {
    final token = _resetTokenFromRoute(route);
    if (token == null || !mounted) return false;
    setState(() => resetToken = token);
    return true;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PBMS Parking',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.brand,
                brightness: Brightness.light,
                surface: AppColors.surface),
            scaffoldBackgroundColor: AppColors.canvas,
            textTheme: ThemeData.light().textTheme.apply(
                bodyColor: AppColors.foreground, displayColor: AppColors.foreground),
            appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.canvas,
                foregroundColor: AppColors.foreground,
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: false),
            cardTheme: CardThemeData(
                color: AppColors.surface,
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    side: const BorderSide(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.md))),
            inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.surfaceMuted,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                labelStyle: const TextStyle(color: AppColors.muted),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.brand, width: 2))),
            filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800))),
            snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.foreground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)))),
        home: resetToken != null
            ? ResetPasswordPage(
                session: session,
                token: resetToken!,
                onComplete: () => setState(() => resetToken = null))
            : session.restoring
            ? const Scaffold(
                body: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AppBrandMark(),
                  SizedBox(height: AppSpace.md),
                  CircularProgressIndicator(),
                  SizedBox(height: AppSpace.sm),
                  Text('Preparing your parking dashboard',
                      style: TextStyle(color: AppColors.muted))
                ])))
            : session.user == null
                ? AuthPage(session: session)
                : Shell(session: session),
      );
}
