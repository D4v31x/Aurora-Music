import 'dart:io';

import 'package:aurora_music_v01/services/expandable_player_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;

import 'services/Audio_Player_Service.dart';
import 'localization/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'localization/locale_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await RiveFile.initialize();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? languageCode = prefs.getString('languageCode') ?? 'en';

  // Track User Data
  await trackUserData();

  //Capture errors
  captureErrors();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AudioPlayerService()),
        ChangeNotifierProvider(create: (context) => ExpandablePlayerController()),
      ],
      child: MyApp(languageCode: languageCode),
    ),
  );

}

Future<void> trackUserData() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Check if user ID already exists
  String? userId = prefs.getString('user_id');
  if (userId == null) {
    // Generate and store new user ID
    userId = DateTime.now().millisecondsSinceEpoch.toString();
    await prefs.setString('user_id', userId);
  }

  // Track last time the app was opened
  String lastOpened = DateTime.now().toIso8601String();
  await prefs.setString('last_opened', lastOpened);

  // Get device information
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  String? deviceModel;

  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    deviceModel = androidInfo.model;
  } else if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    deviceModel = iosInfo.utsname.machine;
  }

  // Send data to Supabase
  await sendDataToSupabase(userId, deviceModel, lastOpened);
}

Future<void> sendDataToSupabase(String userId, String? deviceModel, String lastOpened) async {
  final supabase = Supabase.instance.client;
  final deviceInfo = DeviceInfoPlugin();
  String? androidVersion;
  String? manufacturer;
  String recentErrors = _recentErrors.isNotEmpty ? _recentErrors.join(', ') : 'No recent errors';

  try {
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      androidVersion = androidInfo.version.release;
      manufacturer = androidInfo.manufacturer;
    }

    final response = await supabase
        .from('user_data')
        .upsert({
      'user_id': userId,
      'device_model': deviceModel ?? 'Unknown',
      'manufacturer': manufacturer ?? 'Unknown',
      'android_version': androidVersion ?? 'Unknown',
      'last_opened': lastOpened,
      'recent_errors': recentErrors,
    }, onConflict: 'user_id'); // Use a single column name as a string

    if (response.error != null) {
      print('Error sending data to Supabase: ${response.error!.message}');
    } else {
      print('Data successfully sent to Supabase');
    }
  } catch (e) {
    print('Exception occurred while sending data to Supabase: $e');
  }
}



List<String> _recentErrors = [];

void captureErrors() {
  FlutterError.onError = (FlutterErrorDetails details) {
    _recentErrors.add(details.toString());
    FlutterError.dumpErrorToConsole(details);
  };
}





class MyApp extends StatefulWidget {
  final String languageCode;

  const MyApp({super.key, required this.languageCode});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ui.Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = ui.Locale(widget.languageCode);
  }

  void setLocale(ui.Locale locale) {
    setState(() {
      _locale = locale;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('languageCode', locale.languageCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LocaleProvider(
      locale: _locale,
      setLocale: setLocale,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: _locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          ui.Locale('en', ''),
          ui.Locale('cs', ''),
        ],
        home: const SplashScreen(),
      ),
    );
  }
}
