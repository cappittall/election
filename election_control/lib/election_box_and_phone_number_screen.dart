import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';


class ElectionBoxAndPhoneNumberScreen extends StatefulWidget {
  @override
  _ElectionBoxAndPhoneNumberScreenState createState() => _ElectionBoxAndPhoneNumberScreenState();
}

class _ElectionBoxAndPhoneNumberScreenState extends State<ElectionBoxAndPhoneNumberScreen> {
  final _electionBoxNumberController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  @override
  void dispose() {
    _electionBoxNumberController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _saveValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('electionBoxNumber', int.parse(_electionBoxNumberController.text));
    await prefs.setString('phoneNumber', _phoneNumberController.text);
  }

  InputDecoration _inputDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.red),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
 
final phoneMaskFormatter = MaskTextInputFormatter(
    mask: '0(###) ### ## ##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Seçmen Sandık Numarası ve Telefon Numrası'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Election box number input
              TextField(
                controller: _electionBoxNumberController,
                decoration: _inputDecoration('Seçmen Sandık Numarası'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
              // Phone number input
              TextField(
                controller: _phoneNumberController,
                decoration: _inputDecoration('Telefon Numarası'),
                inputFormatters: [phoneMaskFormatter], 
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 20),
              // Save and continue button
              ElevatedButton(
                onPressed: () async {
                  // Verify the phone number here
                  // If the verification is successful, save the values and navigate to the home page.
                  // Otherwise, show an error message.
                  bool isVerified = true; // Replace this with the actual verification result.
                  if (isVerified) {
                    await _saveValues();
                    Navigator.pushNamed(context, '/homePage');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Telefon numarası doğrulaması başarısız oldu')),
                    );
                  }
                },
                child: Text('Saklayıp devam edin'),
                style: ElevatedButton.styleFrom(
                  primary: Colors.red,
                  onPrimary: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
