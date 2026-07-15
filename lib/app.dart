part of 'main.dart';

class ParkingApp extends StatefulWidget {
  const ParkingApp({super.key});

  @override
  State<ParkingApp> createState() => _ParkingAppState();
}

class _ParkingAppState extends State<ParkingApp> {
  final session = SessionController(ApiClient());

  @override
  void initState() {
    super.initState();
    session.addListener(_refresh);
    session.restore();
  }

  @override
  void dispose() {
    session.removeListener(_refresh);
    session.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PBMS Parking',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: _sky),
          scaffoldBackgroundColor: _background,
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0xfff1f5f9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: Color(0xffe2e8f0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: Color(0xffe2e8f0)),
            ),
          ),
        ),
        home: session.restoring
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : session.user == null
                ? AuthPage(session: session)
                : Shell(session: session),
      );
}
