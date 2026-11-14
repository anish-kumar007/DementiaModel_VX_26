import 'package:firebase_auth/firebase_auth.dart';
import 'hash_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HashService _hashService = HashService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign In with Email and Password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e.code));
    }
  }

  // Sign Up with Email and Password
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      // Optional: Hash password before sending if needed by your backend logic
      // String hashedPassword = await _hashService.hashPassword(password);
      
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e.code));
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Helper to get user-friendly error messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}