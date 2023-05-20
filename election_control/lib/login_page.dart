import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_services.dart';

class LoginPage extends StatelessWidget {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _saveUserToLocal(User? user) async {
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    String email = user.email ?? '';
    String displayName = user.displayName ?? '';
    print('>>>  Email $email, İsim: $displayName ');
    await prefs.setString('displayName', displayName);
    await prefs.setString('email', email);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold( appBar: AppBar(
        title: Text('Seçmen Çift Oy Takip App'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              await _authService.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App title
             
                SizedBox(height: 100),
                // Email text field
               /*  Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Email',
                    ),
                  ),
                ), */
                // Password text field
             /*    Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Şifre',
                    ),
                  ),
                ), */
                /* ElevatedButton(
                  onPressed: () async {
                    final email = _emailController.text.trim();
                    final password = _passwordController.text.trim();
                    if (email.isNotEmpty && password.isNotEmpty) {
                      final userCredential = await _authService.signInWithEmailAndPassword(email, password);
                      if (userCredential != null) {
                        final user = userCredential.user;
                        // Save user data to local storage or perform other actions
                        _saveUserToLocal(user);
                        // Navigate to the election box and phone number screen
                        Navigator.of(context).pushReplacementNamed('/electionBoxAndPhoneNumber');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    primary: Colors.red,
                    onPrimary: Colors.white,
                    textStyle: TextStyle(fontSize: 16),
                  ),
                  child: Text('Email ve şifre ile giriş'),
                ), */
                SizedBox(height: 100,),
                // Google login button
                ElevatedButton.icon(
                  onPressed: () async {
                    final userCredential = await _authService.signInWithGoogle();
                    if (userCredential != null) {              
                      // Save user data to local storage or perform other actions
                      _saveUserToLocal(userCredential.user);
                      // Navigate to the election box and phone number screen
                      Navigator.of(context).pushReplacementNamed('/electionBoxAndPhoneNumber');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    primary: Colors.red,
                    onPrimary: Colors.white,
                    textStyle: TextStyle(fontSize: 16),
                  ),
                  icon: Icon(Icons.login),
                  label: Text('Google ile giriş'),
                ),
                SizedBox(height: 50),
                // Facebook login button
                ElevatedButton.icon(
                  onPressed: () async {
                    UserCredential? userCredential = await _authService.signInWithFacebook();
                   if (userCredential != null) {
                      await _saveUserToLocal(userCredential.user);
                      Navigator.of(context).pushReplacementNamed('/electionBoxAndPhoneNumber');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    primary: Colors.red,
                    onPrimary: Colors.white,
                    textStyle: TextStyle(fontSize: 16),
                  ),
                  icon: Icon(Icons.login),
                  label: Text('Facebook ile giriş'),
                ),
                // Email and password login button
                
              ],
            ),
          ),
        ),
      ),
    );
  }
}