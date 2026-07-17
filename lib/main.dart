import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';


part 'app.dart';
part 'core/api_client.dart';
part 'models/user.dart';
part 'screens/auth_page.dart';
part 'screens/reset_password_page.dart';
part 'widgets/design_system.dart';
part 'widgets/shell.dart';
part 'screens/home_page.dart';
part 'screens/buildings_page.dart';
part 'screens/incident_page.dart';
part 'screens/vehicle_qr_page.dart';
part 'screens/history_wallet_page.dart';
part 'screens/packages_page.dart';
part 'screens/profile_page.dart';

const _sky = AppColors.brand;
const _skyDark = AppColors.brandDeep;
const _background = AppColors.canvas;
const _text = AppColors.foreground;
const _muted = AppColors.muted;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  runApp(const ParkingApp());
}
