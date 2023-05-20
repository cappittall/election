import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FacebookAuth _facebookAuth = FacebookAuth.instance;

  String? _verificationId;

 Future<UserCredential?> signInWithGoogle() async {
  try {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    if (_auth.currentUser == null) {
      // If the user hasn't signed in before, sign them in with the credential
      return await _auth.signInWithCredential(credential);
    } else if (_auth.currentUser!.providerData.any((provider) => provider.providerId == "google.com")) {
      // If the user has already signed in with Google, reauthenticate them with the credential
      return await _auth.currentUser!.reauthenticateWithCredential(credential); // Updated this line
    } else {
      // If the user has signed in with a different provider, link the new credential to their account
      await _auth.currentUser!.linkWithCredential(credential);
      return await _auth.currentUser!.reauthenticateWithCredential(credential);
    }
  } catch (e) {
    print(e);
    return null;
  }
}

Future<UserCredential?> signInWithFacebook() async {
  try {
    final LoginResult result = await _facebookAuth.login(permissions: ['email', 'public_profile']);

    // Add a null check for the result
    if (result.status != LoginStatus.success) return null;

    final OAuthCredential credential = FacebookAuthProvider.credential(result.accessToken!.token);

    try {
      // Sign in with the credential directly
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        final email = e.email;
        if (email != null) {
          final signInMethods = await _auth.fetchSignInMethodsForEmail(email);

          // Sign in the user using the original provider (Google in this case)
          if (signInMethods.contains("google.com")) {
            final googleUser = await GoogleSignIn().signIn();
            final googleAuth = await googleUser?.authentication;
            final googleCredential = GoogleAuthProvider.credential(
              accessToken: googleAuth?.accessToken,
              idToken: googleAuth?.idToken,
            );
            final userCredential = await _auth.signInWithCredential(googleCredential);

            // Link the Facebook credential to the user's account
            if (userCredential.user != null) {
              await userCredential.user!.linkWithCredential(credential);
              return userCredential;
            }
          }
        }
      } else {
        print(e);
      }
      return null;
    }
  } catch (e) {
    print(e);
    return null;
  }
}




  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
  try {
    final UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return userCredential;
  } on FirebaseAuthException catch (e) {
    // If the user doesn't exist, create an account
    if (e.code == 'user-not-found') {
      try {
        final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        return userCredential;
      } catch (e) {
        print(e);
        return null;
      }
    }
    print(e);
    return null;
  }
}


  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _facebookAuth.logOut();
      await _auth.signOut();
    } catch (e) {
      print(e);
    }
  }

  Future<String?> sendPhoneNumberVerification(String phoneNumber) async {
    try {
      final PhoneCodeSent codeSent = (String verificationId, int? forceResendingToken) async {
        // Save the verificationId
        _verificationId = verificationId;
      };

      final PhoneVerificationCompleted verificationCompleted = (PhoneAuthCredential phoneAuthCredential) {
        // Handle automatic code verification and sign-in
      };

      final PhoneVerificationFailed verificationFailed = (FirebaseAuthException exception) {
        print('Verification failed: ${exception.message}');
      };

      final PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout = (String verificationId) {
        // Handle auto-retrieval timeout
      };

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      );

      return null;
    } catch (e) {
      print(e);
      return 'Failed to send verification code';
    }
  }

    Future<UserCredential?> signInWithPhoneNumber(String smsCode) async {
    try {
      final AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print(e);
      return null;
    }
  }
Future<UserCredential?> linkWithGoogle(User currentUser) async {
  try {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    if (currentUser.providerData.any((element) => element.providerId == 'google.com')) {
      // The user is already linked with a Google account
      return null;
    } else {
      return await currentUser.linkWithCredential(credential);
    }
  } catch (e) {
    print(e);
    return null;
  }
}

Future<UserCredential?> linkWithFacebook(User currentUser) async {
  try {
    final LoginResult result = await _facebookAuth.login(permissions: ['email', 'public_profile']);

    if (result.status != LoginStatus.success) return null;

    final OAuthCredential credential = FacebookAuthProvider.credential(result.accessToken!.token);

    if (currentUser.providerData.any((element) => element.providerId == 'facebook.com')) {
      // The user is already linked with a Facebook account
      return null;
    } else {
      return await currentUser.linkWithCredential(credential);
    }
  } catch (e) {
    print(e);
    return null;
  }
}

Future<UserCredential?> linkWithPhoneNumber(User currentUser, String smsCode) async {
  try {
    final AuthCredential credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );

    if (currentUser.providerData.any((element) => element.providerId == 'phone')) {
      // The user is already linked with a phone number
      return null;
    } else {
      return await currentUser.linkWithCredential(credential);
    }
  } catch (e) {
    print(e);
    return null;
  }
}

Future<void> unlinkAccount(String providerId) async {
  try {
    await _auth.currentUser!.unlink(providerId);
  } catch (e) {
    print(e);
  }
}

}