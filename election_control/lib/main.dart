import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'login_page.dart';
import 'election_box_and_phone_number_screen.dart';
import 'home_page.dart';

// Initialize app and check for user preferences
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final electionBoxNumber = prefs.getInt('electionBoxNumber');
  final phoneNumber = prefs.getString('phoneNumber');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp(electionBoxNumber: electionBoxNumber, phoneNumber: phoneNumber));
}

class MyApp extends StatelessWidget {
  final int? electionBoxNumber;
  final String? phoneNumber;

  MyApp({this.electionBoxNumber, this.phoneNumber});

  // Set up routes for different screens
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.red,
        accentColor: Colors.redAccent,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            primary: Colors.red,
            onPrimary: Colors.white,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.red),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            if (electionBoxNumber != null && phoneNumber != null) {
              return MaterialPageRoute(builder: (context) => HomePage());
            } else {
              return MaterialPageRoute(builder: (context) => LoginPage());
            }
          case '/homePage':
            if (electionBoxNumber != null && phoneNumber != null) {
              return MaterialPageRoute(builder: (context) => HomePage());
            } else {
              return MaterialPageRoute(builder: (context) => ElectionBoxAndPhoneNumberScreen());
            }
          case '/electionBoxAndPhoneNumber':
            return MaterialPageRoute(builder: (context) => ElectionBoxAndPhoneNumberScreen());
          default:
            return null;
        }
      },
      // Set default unknown route
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (context) => LoginPage());
      },
    );
  }
}
