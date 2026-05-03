import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/ana_ekran.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A1628),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const CaveApp());
}

class CaveApp extends StatelessWidget {
  const CaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CaveApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AnaEkran(),
    );
  }
}
