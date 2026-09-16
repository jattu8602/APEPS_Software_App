import 'package:flutter/material.dart';
import '../services/app_update_service.dart';

class AppUpdateDialog extends StatefulWidget {
  final String? newVersion;
  final bool isMandatory;

  const AppUpdateDialog({
    super.key,
    this.newVersion,
    this.isMandatory = false,
  });

  static Future<void> show(
    BuildContext context, {
    String? newVersion,
    bool isMandatory = false,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (BuildContext context) => AppUpdateDialog(
        newVersion: newVersion,
        isMandatory: isMandatory,
      ),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;

  void _onDownloadNowPressed() async {
    setState(() {
      _isDownloading = true;
    });

    final success = await AppUpdateService.startFlexibleUpdate();

    if (mounted) {
      setState(() {
        _isDownloading = false;
      });

      if (!success) {
        // Fallback: Open Play Store page directly
        await AppUpdateService.openPlayStorePage();
      }

      if (mounted && !widget.isMandatory) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isMandatory,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 16,
        backgroundColor: const Color(0xFF18181B), // Dark zinc background
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  size: 44,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "App Update Available!",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.newVersion != null && widget.newVersion!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF673AB7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "v${widget.newVersion}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9333EA),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                "A brand new version of APEPS is ready. Update now to enjoy the latest features and speed improvements!",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  onPressed: _isDownloading ? null : _onDownloadNowPressed,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.file_download_rounded, size: 22),
                  label: Text(
                    _isDownloading ? "Downloading..." : "Download Now",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (!widget.isMandatory) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    "Later",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
