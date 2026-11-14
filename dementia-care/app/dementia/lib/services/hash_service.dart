import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashService {
  Future<String> hashPassword(String password) async {
    // Convert password to bytes
    final bytes = utf8.encode(password);
    
    // Generate SHA-256 hash
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }
}