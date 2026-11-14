import 'package:material_ui/material_ui.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../widgets/large_action_card.dart';
import '../widgets/sos_emergency_button.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

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
              const SizedBox(height: 20),
              Expanded(
                child: LargeActionCard(
                  title: AppConstants.playGamesLabel,
                  icon: Icons.extension,
                  onTap: () {
                    // Navigate to Game 1
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LargeActionCard(
                  title: AppConstants.safeZoneLabel,
                  icon: Icons.location_on,
                  color: AppTheme.statusCardColor,
                  onTap: () {
                    // Show Safe Zone / Geofencing information
                  },
                ),
              ),
              const SizedBox(height: 24),
              SosEmergencyButton(
                onPressed: () {
                  // Trigger SOS emergency action
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}