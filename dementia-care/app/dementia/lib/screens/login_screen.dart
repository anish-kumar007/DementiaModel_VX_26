import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _pinController = TextEditingController();
  final _walletController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();
  bool _isLoading = false;

  void _handlePatientLogin() async {
    if (_pinController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 6-digit PIN')),
      );
      return;
    }

    setState(() => _isLoading = true);
    String? storedHash = await _secureStorage.read(key: 'patient_pin_hash');

    if (storedHash == null) {
      // First time setup
      String newHash = await _authService.setupPatientPin(_pinController.text);
      await _secureStorage.write(key: 'patient_pin_hash', value: newHash);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN Setup Complete!')),
      );
    } else {
      // Login
      final isValid = await _authService.loginPatient(_pinController.text, storedHash);
      if (isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient Login Successful!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid PIN')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  void _handleCaregiverLogin() async {
    if (_walletController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a private key')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final isValid = await _authService.loginCaregiver(_walletController.text);
    
    if (isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web3 Login Successful!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web3 Authentication Failed')),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _pinController.dispose();
    _walletController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dementia Care Login'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Patient (PIN)', icon: Icon(Icons.pin)),
              Tab(text: 'Caregiver (Web3)', icon: Icon(Icons.wallet)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Patient Region
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Enter your 6-digit PIN', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '******'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handlePatientLogin,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: _isLoading ? const CircularProgressIndicator() : const Text('Login / Setup PIN'),
                  ),
                ],
              ),
            ),
            // Caregiver Region
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Connect Wallet to Manage Account', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _walletController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Wallet Private Key (Dev Only)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  const Text('*In production, use WalletConnect.', style: TextStyle(color: Colors.red, fontSize: 12)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleCaregiverLogin,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: _isLoading ? const CircularProgressIndicator() : const Text('Sign Challenge (Web3)'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
