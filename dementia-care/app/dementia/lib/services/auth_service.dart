import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<Map<String, dynamic>> signInWithEmail(String email, String password) async {
    try {
      print('🔑 Attempting login for: $email');
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('✅ Auth successful. Fetching Firestore profile for UID: ${userCredential.user!.uid}');
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      
      if (userDoc.exists) {
        print('✅ Profile found. Role: ${userDoc['role']}');
        return {'user': userCredential.user, 'role': userDoc['role']};
      } else {
        print('❌ Profile NOT found in Firestore.');
        throw Exception('User profile not found. Please register again.');
      }
    } on FirebaseException catch (e) {
      print('🔥 FIREBASE AUTH ERROR: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e.code));
    } catch (e) {
      print('🔥 UNEXPECTED ERROR: $e');
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Map<String, dynamic>> signUpWithEmail(String email, String password, String role) async {
    try {
      print('📝 Attempting registration for: $email as $role');
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Auth created. Writing to Firestore...');
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ Firestore write successful!');

      return {'user': userCredential.user, 'role': role};
    } on FirebaseException catch (e) {
      print('🔥 FIREBASE REGISTER ERROR: ${e.code} - ${e.message}');
      throw Exception(_getErrorMessage(e.code));
    } catch (e) {
      print('🔥 UNEXPECTED REGISTER ERROR: $e');
      throw Exception('Registration failed: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found': return 'No user found for that email.';
      case 'wrong-password': return 'Wrong password.';
      case 'email-already-in-use': return 'Email already registered.';
      case 'invalid-email': return 'Invalid email.';
      case 'weak-password': return 'Password must be at least 6 characters.';
      case 'permission-denied': return 'Database permission denied. Check Firestore Rules.';
      default: return 'An error occurred: $code';
    }
  }
}