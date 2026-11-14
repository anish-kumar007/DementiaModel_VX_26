import 'hash_service.dart';
import 'web3_service.dart';

class AuthService {
  final HashService _hashService = HashService();
  final Web3Service _web3Service = Web3Service();

  Future<bool> loginPatient(String pin, String storedHash) async {
    return await _hashService.verifyHash(pin, storedHash);
  }

  Future<String> setupPatientPin(String pin) async {
    return await _hashService.createHash(pin);
  }

  Future<bool> loginCaregiver(String privateKeyHex) async {
    final challenge = _web3Service.generateChallenge();
    final signature = await _web3Service.signChallenge(privateKeyHex, challenge);
    // In production, send signature to backend to verify. Here we just check if it worked.
    return signature != null;
  }
}