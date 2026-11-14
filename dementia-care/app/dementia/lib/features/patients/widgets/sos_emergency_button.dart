import 'package:material_ui/material_ui.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';

class SosEmergencyButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isSending;

  const SosEmergencyButton({
    super.key,
    required this.onPressed,
    this.isSending = false,
  });

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
        onPressed: isSending ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSending)
              const CircularProgressIndicator(color: Colors.white)
            else
              const Icon(Icons.warning_amber_rounded, size: 40, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              isSending ? 'SENDING SOS...' : AppConstants.sosEmergencyLabel,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
