import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

enum CustomUpdateStatus {
  updateAvailable,
  noUpdateAvailable,
  updateInProgress,
  updateDownloaded,
  error,
}

class AppUpdateCheckResult {
  final CustomUpdateStatus status;
  final AppUpdateInfo? appUpdateInfo;
  final String? errorMessage;

  AppUpdateCheckResult({
    required this.status,
    this.appUpdateInfo,
    this.errorMessage,
  });
}

class AppUpdateService {
  static const String _playStoreAppId = 'com.calmchase.ssb';

  /// Check if an app update is available on Google Play Store
  static Future<AppUpdateCheckResult> checkForUpdate() async {
    if (!Platform.isAndroid) {
      return AppUpdateCheckResult(status: CustomUpdateStatus.noUpdateAvailable);
    }

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      debugPrint("🚀 [AppUpdate] Check status: ${updateInfo.updateAvailability}");

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        return AppUpdateCheckResult(
          status: CustomUpdateStatus.updateAvailable,
          appUpdateInfo: updateInfo,
        );
      } else if (updateInfo.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress) {
        return AppUpdateCheckResult(
          status: CustomUpdateStatus.updateInProgress,
          appUpdateInfo: updateInfo,
        );
      } else {
        return AppUpdateCheckResult(
          status: CustomUpdateStatus.noUpdateAvailable,
          appUpdateInfo: updateInfo,
        );
      }
    } catch (e) {
      debugPrint("🚀 [AppUpdate] Exception checking update: $e");
      return AppUpdateCheckResult(
        status: CustomUpdateStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Start flexible update download in the background
  static Future<bool> startFlexibleUpdate() async {
    try {
      final AppUpdateResult result = await InAppUpdate.startFlexibleUpdate();
      debugPrint("🚀 [AppUpdate] Flexible update download result: $result");
      if (result == AppUpdateResult.success) {
        await InAppUpdate.completeFlexibleUpdate();
        return true;
      }
    } catch (e) {
      debugPrint("🚀 [AppUpdate] Flexible update failed: $e, redirecting to store...");
      return await openPlayStorePage();
    }
    return false;
  }

  /// Perform immediate update for critical app updates
  static Future<bool> performImmediateUpdate() async {
    try {
      final AppUpdateResult result = await InAppUpdate.performImmediateUpdate();
      return result == AppUpdateResult.success;
    } catch (e) {
      debugPrint("🚀 [AppUpdate] Immediate update failed: $e");
      return await openPlayStorePage();
    }
  }

  /// Open Google Play Store page directly for manual download
  static Future<bool> openPlayStorePage() async {
    try {
      final Uri playStoreUri = Uri.parse(
        'https://play.google.com/store/apps/details?id=$_playStoreAppId',
      );
      if (await canLaunchUrl(playStoreUri)) {
        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      debugPrint("🚀 [AppUpdate] Error opening Play Store page: $e");
    }
    return false;
  }
}
