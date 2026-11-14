import 'package:password_guard/password_guard.dart';

class HashService {
  Future<String> createHash(String pin) async {
    final result = await PasswordGuard.hash(password: pin);
    return result.hash;
  }

  Future<bool> verifyHash(String pin, String storedHash) async {
    return await PasswordGuard.verify(password: pin, hash: storedHash);
  }
}