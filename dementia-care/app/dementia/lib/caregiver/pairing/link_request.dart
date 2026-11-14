// app/lib/caregiver/pairing/link_request.dart
// The ONLY place that talks to B's request helper (replaces cloud_functions).
// B's helper writes a request doc, listens for the answer and times out after
// 10 s for pairing. Wire it in at the marked line once B's helper is pushed.

/// Thrown for a clear failure answer. code is one of:
/// 'not-found', 'expired', 'used', 'locked', 'denied'.
class LinkError implements Exception {
  LinkError(this.code);
  final String code;
}

class LinkResult {
  LinkResult(this.pid, this.name);
  final String pid;
  final String? name;
}

/// Sends the 6-digit code and returns the linked patient.
/// Must throw LinkError for a refused code, and TimeoutException after 10 s.
Future<LinkResult> requestLink(String code) async {
  // TODO(B's helper): replace this block with the real call, for example:
  //   final answer = await requestAndWait('link_with_code', {'code': code},
  //       timeout: const Duration(seconds: 10));
  //   if (answer['error'] != null) throw LinkError(answer['error'] as String);
  //   return LinkResult(answer['pid'] as String, answer['name'] as String?);
  throw UnimplementedError('Connect B\'s request helper in link_request.dart');
}