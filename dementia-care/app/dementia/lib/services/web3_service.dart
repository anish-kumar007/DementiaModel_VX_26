import 'dart:convert';
import 'dart:typed_data';

import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

class Web3Service {
  // Public RPC for Sepolia testnet (swap for Alchemy/Infura in production)
  final String rpcUrl = "https://rpc.sepolia.org";
  late final Web3Client _client;

  Web3Service() {
    _client = Web3Client(rpcUrl, Client());
  }

  // Caregiver signs this to prove wallet ownership
  String generateChallenge() {
    return "Dementia Care Authentication Challenge: ${DateTime.now().millisecondsSinceEpoch}";
  }

  Future<String?> signChallenge(String privateKeyHex, String challenge) async {
    try {
      final credentials = EthPrivateKey.fromHex(privateKeyHex);

      // FIX: signPersonalMessage wants Uint8List, not String
      final messageBytes = Uint8List.fromList(utf8.encode(challenge));
      final signature = await credentials.signPersonalMessage(messageBytes);

      // FIX: no bytesToHex import needed — local helper
      return _bytesToHex(signature);
    } catch (e) {
      print("Web3 Signing Error: $e");
      return null;
    }
  }

  String _bytesToHex(List<int> bytes) {
    final buffer = StringBuffer('0x');
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}