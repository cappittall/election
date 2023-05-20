package com.example.turkish_election_control

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import com.facebook.FacebookSdk // Add this line

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        FacebookSdk.setAutoInitEnabled(true) // Add this line
        FacebookSdk.fullyInitialize() // Add this line
    }
}
