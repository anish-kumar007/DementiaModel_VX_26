import 'package:material_ui/material_ui.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';

class SosEmergencyButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SosEmergencyButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.sosRedColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
        ),
        onPressed: onPressed,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size:40, color: Colors.white),
            SizedBox(width: 12),
            Text(
              AppConstants.sosEmergencyLabel,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
