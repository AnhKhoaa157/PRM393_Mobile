import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

part 'app.dart';
part 'core/api_client.dart';
part 'models/user.dart';
part 'screens/auth_page.dart';
part 'widgets/shell.dart';
part 'screens/home_page.dart';
part 'screens/reservations_page.dart';
part 'screens/history_wallet_page.dart';
part 'screens/packages_page.dart';
part 'screens/profile_page.dart';

const _sky = Color(0xff0ea5e9);
const _skyDark = Color(0xff0369a1);
const _background = Color(0xfff8fafc);
const _text = Color(0xff0f172a);
const _muted = Color(0xff64748b);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  runApp(const ParkingApp());
}
