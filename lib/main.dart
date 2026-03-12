import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tabulation_systemv7/splash_screen.dart';
import 'package:tabulation_systemv7/services/update_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Activate Firebase App Check with debug provider for development
  // await FirebaseAppCheck.instance.activate(
  //   androidProvider: AndroidProvider.debug,
  // );

  // Start periodic update checking - disabled to prevent auto updates when making changes
  // UpdateService().startPeriodicUpdateCheck();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase Auth',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashScreen(),
    );
  }
}
