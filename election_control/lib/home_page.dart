import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:image_crop/image_crop.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'auth_services.dart';
import 'constant.dart';
import 'dublicate_voter_page.dart';






class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _voterLineNumberController = TextEditingController();
  late int electionBoxNumber;
  late String phoneNumber;
  late String displayName;
  late String email;
  late Position _currentPosition;
  File? _image;
  final AuthService _authService = AuthService();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUserData().then((_) {
      _getCurrentLocation();
    });
  }

  Future<Map<String, dynamic>> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    electionBoxNumber = prefs.getInt('electionBoxNumber') ?? 0;
    phoneNumber = prefs.getString('phoneNumber') ?? '';
    displayName = prefs.getString('displayName') ?? '';
    email = prefs.getString('email') ?? '';
     print( '>>>  Email $email, İsim: $displayName ');
    return {
      'electionBoxNumber': electionBoxNumber,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'email': email,
    };
  }

  Future<void> _getCurrentLocation() async {
    bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationServiceEnabled) {
      // Location services are not enabled on the device
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied, take the user to settings
      return;
    }

    _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }


Future<ui.Image> loadImage(Uint8List imgBytes) async {
  final Completer<ui.Image> completer = Completer();
  ui.decodeImageFromList(imgBytes, (ui.Image img) {
    return completer.complete(img);
  });
  return completer.future;
}

Future<File> saveImage(ui.Image image, String path,
    {ui.ImageByteFormat format = ui.ImageByteFormat.png}) async {
  final ByteData? byteData =
      await image.toByteData(format: format);
  final buffer = byteData!.buffer;
  return File(path).writeAsBytes(
      buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
}

Future<ui.Image> cropImage(ui.Image image, Rect rect) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Paint paint = Paint();
  canvas.drawImageRect(
      image, rect, Rect.fromLTWH(0, 0, rect.width, rect.height), paint);
  final ui.Image croppedImage =
      await recorder.endRecording().toImage(rect.width.toInt(), rect.height.toInt());
  return croppedImage;
}

Future<void> _pickImage() async {
  final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
  if (pickedFile != null) {
    // Create a new file with the desired name
    final String newName = '$electionBoxNumber\_${_voterLineNumberController.text}.jpg';
    final String newPath = p.join(p.dirname(pickedFile.path), newName);

    // Copy the picked image to the new file
    final File newImageFile = await File(pickedFile.path).copy(newPath);

    setState(() {
      _image = newImageFile;
    });
  }
}

Future<void> _pickImageWithFacedetect() async {
  setState(() { _isSubmitting = true; });
  final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
  if (pickedFile != null) {
    // Create an input image from the picked file
    final inputImage = InputImage.fromFilePath(pickedFile.path);

    // Create a FaceDetector instance
    final options = FaceDetectorOptions();
    final faceDetector = FaceDetector(options: options);

    // Detect faces in the input image
    List<Face> faces = await faceDetector.processImage(inputImage);

    // Dispose the FaceDetector instance when done
    faceDetector.close();

    if (faces.isNotEmpty) {
      // Get the first face detected
      Face face = faces.first;

      // Load the image as a dart:ui Image
      final imageFile = File(pickedFile.path);
      final ui.Image originalImage =
          await loadImage(Uint8List.fromList(imageFile.readAsBytesSync()));

      // Crop the face from the image
      final croppedImage = await cropImage(originalImage, face.boundingBox);

      // Save the cropped image to a new file
      final String newName =
          '$electionBoxNumber\_${_voterLineNumberController.text}.jpg';
      final String newPath = p.join(p.dirname(pickedFile.path), newName);
      final File newImageFile =
          await saveImage(croppedImage, newPath, format: ui.ImageByteFormat.png);

      setState(() {
        _image = newImageFile;
        _isSubmitting = false; 
      });
    } else {
      // No face detected, handle it as needed
      print('No face detected');
    }
  }
}



Future<Uint8List> resizeImage(File imageFile, int newSize) async {
  Uint8List imageData = await imageFile.readAsBytes();
  img.Image? image = img.decodeImage(imageData);

  if (image != null) {
    img.Image resizedImage = img.copyResize(image, height: newSize);
    return img.encodeJpg(resizedImage);
  } else {
    throw Exception('Failed to decode image');
  }
}


Future<void> _submitData() async {
  setState(() { _isSubmitting = true; });
  Uint8List resizedImageData = await resizeImage(_image!, 560*2);

  http.MultipartRequest request = http.MultipartRequest(
    'POST',
    Uri.parse('$connectionUrl/voter-submit/'),
  );

  request.headers['Content-Type'] = 'multipart/form-data';
  request.fields['electionBoxNumber'] = electionBoxNumber.toString();
  request.fields['phoneNumber'] = phoneNumber;
  request.fields['userName'] = '$displayName!'; 
  request.fields['email'] = '$email!'; 
  request.fields['voterLineNumber'] = _voterLineNumberController.text;
  request.fields['latitude'] = _currentPosition.latitude.toString();
  request.fields['longitude'] = _currentPosition.longitude.toString();
  request.fields['timestamp'] = (DateTime.now().millisecondsSinceEpoch/1000).toString();
  
  request.files.add(http.MultipartFile.fromBytes(
    'image',
    resizedImageData,
     //File(_image!.path).readAsBytesSync(),
    filename: p.basename(_image!.path),
    contentType: MediaType('image', 'jpeg'), // Change 'jpeg' to your image format
  ));

  try {
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    setState(() {_isSubmitting = false; });

    if (response.statusCode == 200) {
      print("Data sent successfully!");
      final responseData = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      print('Statüs $responseData');
      Navigator.push(
          context as BuildContext,
          MaterialPageRoute(
            builder: (context) => DuplicateVoterPage(responseData: responseData, currentVoterImage: _image),
          ),
        );


    } else {
      print("Failed to send data.");
    }
  } catch (e) {
    print("Error while sending data: $e");
  }
}




@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Ana Sayfa'),
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
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder(
          future: _loadUserData(),
          builder: (context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              electionBoxNumber = snapshot.data?['electionBoxNumber'] ?? 0;
              phoneNumber = snapshot.data?['phoneNumber'] ?? '';
              displayName = snapshot.data?['displayName'] ?? '';

              return Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10),
                    Text('Sayın, $displayName - $email', style: TextStyle(fontSize: 15)),
                    SizedBox(height: 20),
                    // Election box number input field
                    TextFormField(
                      controller: TextEditingController(text: electionBoxNumber.toString()),
                      decoration: InputDecoration(
                        labelText: 'Seçmen Sandık Numarası',
                        labelStyle: TextStyle(color: Colors.red),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen seçmen sandık numarasını giriniz!';
                        }
                        return null;
                      },
                      onSaved: (value) => electionBoxNumber = int.parse(value!),
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: TextEditingController(text: phoneNumber.toString()),
                      decoration: InputDecoration(
                        labelText: 'Telefon numarası',
                        labelStyle: TextStyle(color: Colors.red),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen telefon numarasını giriniz...';
                        }
                        return null;
                      },
                      onSaved: (value) => phoneNumber = value!,
                    ),
                    // Display phone number
                    
                    SizedBox(height: 20),
                    // Voter line number input field
                    TextFormField(
                      controller: _voterLineNumberController,
                      decoration: InputDecoration(
                        labelText: 'Seçmen Sıra No ',
                        labelStyle: TextStyle(color: Colors.red),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen seçmen sıra numarasını giriniz...';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                   Center(
                      child: _isSubmitting
                          ? CircularProgressIndicator()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Button to capture voter image
                                    ElevatedButton(
                                      onPressed: _pickImage,
                                      child: Text('Seçmenin fotoğrafını çekin'),
                                    ),
                                    // Display selected image thumbnail
                                    if (_image != null)
                                      SizedBox(
                                        width: 200,
                                        height: 200,
                                        child: Image.file(_image!),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 20),
                                // Button to submit data
                                Center(
                                  child: ElevatedButton(
                                    onPressed: _submitData,
                                    child: Text('Gönder'),
                                  ),
                                ),
                              ],
                            ),
                    )
                  ],
                ),
              );
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    ),
  );
}
}