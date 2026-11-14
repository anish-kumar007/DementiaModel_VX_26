import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../widgets/large_action_card.dart';
import '../widgets/sos_emergency_button.dart';
import '../services/sos_service.dart';
import '../services/location_service.dart';
import 'game1_screen.dart';
import 'game2_screen.dart';
import 'pairing_code_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  bool _isSendingSos = false;

  @override
  void initState() {
    super.initState();
    // Initialize location & battery exemption flow on startup
    LocationService.initializeLocationAndBatteryExemption();
  }

  Future<void> _handleSosPress() async {
    setState(() => _isSendingSos = true);
    final triggered = await SosService.triggerEmergencySos();

    if (!mounted) return;
    setState(() => _isSendingSos = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          triggered
              ? 'Emergency SOS triggered! Opening SMS fallback...'
              : 'Could not send SOS. Please call your caregiver.',

          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: triggered ? Colors.orange.shade800 : Colors.red.shade900,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _openGameSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose a Game',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCardColor,
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const Game1Screen()));
              },
              child: const Text('Game 1: Memory Match', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryCardColor,
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const Game2Screen()));
              },
              child: const Text('Game 2: Story & Word Recall', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppConstants.appTitle,
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LargeActionCard(
                  title: AppConstants.playGamesLabel,
                  icon: Icons.extension,
                  color: AppTheme.primaryCardColor,
                  onTap: _openGameSelector,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: LargeActionCard(
                        title: AppConstants.safeZoneLabel,
                        icon: Icons.location_on,
                        color: AppTheme.statusCardColor,
                        onTap: () {
                          // TODO: Geofence & Consent screen (Hours 12-16)
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: LargeActionCard(
                        title: AppConstants.pairDeviceLabel,
                        icon: Icons.link,
                        color: AppTheme.pairingCardColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PairingCodeScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SosEmergencyButton(
                isSending: _isSendingSos,
                onPressed: _handleSosPress,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

