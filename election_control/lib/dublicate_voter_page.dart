import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import './constant.dart';

class DuplicateVoterPage extends StatelessWidget {
  final Map<String, dynamic> responseData;
  final File? currentVoterImage;


  const DuplicateVoterPage({required this.responseData, Key? key, this.currentVoterImage}) : super(key: key);

  Widget _buildBorderedText(String text, bool reverse, {bold=false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: reverse ? Colors.red : Colors.white,
        border: Border.all(color: Colors.redAccent, width: 2.0),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
      text,
      style: TextStyle(
        color: reverse ? Colors.white : Color.fromARGB(255, 143, 5, 5),
        fontWeight: bold ? FontWeight.bold: FontWeight.normal, // Add this line for bold text
        ),
      ),
    );
  }

  Future<void> openGoogleMapsOrCall(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }


 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Cift oy kullanma durumu'),
      backgroundColor: Colors.redAccent,
    ),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          _buildBorderedText(responseData['message'], true),
          _buildBorderedText('Sandık Numarası: ${responseData['election_box_number']??""}', false),
          _buildBorderedText('Seçmen listesi sırano: ${responseData['voter_line_number']??""}', false),
          InkWell(
            onTap: () {
              String latitude = responseData['latitude'].toString();
              String longitude = responseData['longitude'].toString();
              String url = 'https://www.google.com/maps?q=$latitude,$longitude';
              openGoogleMapsOrCall(url);
            },
            child: _buildBorderedText('Yeri: ${responseData['latitude']??""}, ${responseData['longitude']??""}', false, bold:true),
          ),
          _buildBorderedText('Gönderen: ${responseData['user_name']??""}', false),
          _buildBorderedText('Email: ${responseData['email']??""}', false),
          InkWell(
            onTap: () {
              String url = 'tel:${responseData['phone_number']??""}';
              openGoogleMapsOrCall(url);
            },
            child: _buildBorderedText('Telefon Numarası: ${responseData['phone_number']??""}', false, bold:true),
          ),

          _buildBorderedText('Oy kullanma saati: ${responseData['timestamp']??""}', false),
          // Display both images side by side
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
            // Display previous voter's image with face rectangle
            responseData['image_path'] != null
                ? SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      children: [
                        Image.network('$connectionUrl/${responseData['image_path']}'),
                        if (responseData['face_rectangele_previous'] != null) 
                        CustomPaint(
                          painter: FaceRectanglePainter(
                            faceRectangle: jsonDecode(jsonEncode(responseData['face_rectangele_previous'])),
                          ),
                        ),
                      ],
                    ),
                  )
                : SizedBox(),
              // Display current voter's image with face rectangle
              currentVoterImage != null
                  ? SizedBox(
                      width: 150,
                      height: 150,
                      child: Stack(
                        children: [
                          Image.file(currentVoterImage!),
                          if (responseData['face_rectangle_recent'] != null)
                          CustomPaint(
                            painter: FaceRectanglePainter(
                              faceRectangle: jsonDecode(jsonEncode(responseData['face_rectangle_recent']))
                            ),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(),
            ],
          ),
        ],
      ),
    ),
  );
}
}


class FaceRectanglePainter extends CustomPainter {
  final Map<String, dynamic> faceRectangle;

  FaceRectanglePainter({required this.faceRectangle});

    @override
  void paint(Canvas canvas, Size size) {
    if (faceRectangle != null) {
      double left = faceRectangle['x'].toDouble();
      double top = faceRectangle['y'].toDouble();
      double width = faceRectangle['width'].toDouble();
      double height = faceRectangle['height'].toDouble();

      Rect rect = Rect.fromLTWH(left, top, width, height);

      final paint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(rect, paint);
    }
  }


  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}