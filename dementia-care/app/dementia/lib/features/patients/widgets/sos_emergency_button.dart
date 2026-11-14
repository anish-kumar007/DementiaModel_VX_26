import 'package:material_ui/material_ui.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';

class SosEmergencyButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isSending;
  final String? labelOverride;

  const SosEmergencyButton({
    super.key,
    required this.onPressed,
    this.isSending = false,
    this.labelOverride,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.sosRedColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 6,
        ),
        onPressed: isSending ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSending)
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
            else
              const Icon(Icons.sos, size: 40, color: Colors.white),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                isSending
                    ? 'SENDING SOS...'
                    : (labelOverride ?? AppConstants.sosEmergencyLabel),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
