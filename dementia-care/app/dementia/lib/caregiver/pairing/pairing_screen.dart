// app/lib/caregiver/pairing/pairing_screen.dart
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../common.dart';
import '../dashboard/dashboard_screen.dart';
import 'link_request.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});
  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Kind, plain messages for each failure.
  String _friendly(LinkError e) {
    switch (e.code) {
      case 'not-found':
        return 'That code was not found. Please check the 6 digits.';
      case 'expired':
      case 'used':
        return 'That code has expired or was already used. Ask for a new one on the patient phone.';
      case 'locked':
        return 'Too many tries. Please wait a little and try again.';
      case 'denied':
        return 'This account cannot link to a patient. Sign in as a family member.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  Future<void> _link() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Please enter all 6 digits.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await requestLink(code);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DashboardScreen(pid: res.pid)),
      );
    } on LinkError catch (e) {
      setState(() => _error = _friendly(e));
    } on TimeoutException {
      setState(() => _error = 'No answer yet. Check the internet and try again.');
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link to a patient')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the 6-digit code shown on the patient\'s phone.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('The code works once and expires in 10 minutes.'),
            const SizedBox(height: 24),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 36, letterSpacing: 12),
              decoration: InputDecoration(
                counterText: '',
                border: const OutlineInputBorder(),
                errorText: _error,
                errorMaxLines: 3,
              ),
              onSubmitted: (_) => _link(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _busy ? null : _link,
                child: _busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3))
                    : const Text('Link', style: TextStyle(fontSize: 20)),
              ),
            ),
            const Spacer(),
            Text(disclaimer,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}