import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppReviewService {
  static final InAppReview _inAppReview = InAppReview.instance;
  static const String _playStoreAppId = 'com.calmchase.ssb';
  static const String _prefLastPromptKey = 'last_review_prompt_timestamp';
  static const String _prefPromptCountKey = 'review_prompt_count';

  /// Request in-app rating using Google Play In-App Review API,
  /// falling back to opening Play Store listing if native in-app review is unavailable.
  static Future<bool> requestAppReview({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!force) {
        final lastPrompt = prefs.getInt(_prefLastPromptKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        // Don't prompt again if user was prompted in the last 14 days
        if (now - lastPrompt < 14 * 24 * 60 * 60 * 1000) {
          debugPrint("⭐ [AppReview] Skipped: Prompted recently");
          return false;
        }
      }

      final isAvailable = await _inAppReview.isAvailable();
      debugPrint("⭐ [AppReview] Native In-App Review available: $isAvailable");

      if (isAvailable) {
        await _inAppReview.requestReview();
        await _recordPrompt(prefs);
        return true;
      } else {
        return await openStoreListing();
      }
    } catch (e) {
      debugPrint("⭐ [AppReview] Error requesting review: $e");
      return await openStoreListing();
    }
  }

  /// Direct link to Google Play Store listing page
  static Future<bool> openStoreListing() async {
    try {
      debugPrint("⭐ [AppReview] Opening Store Listing for $_playStoreAppId");
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.openStoreListing(appStoreId: _playStoreAppId);
        return true;
      } else {
        final Uri playStoreUri = Uri.parse(
          'https://play.google.com/store/apps/details?id=$_playStoreAppId',
        );
        if (await canLaunchUrl(playStoreUri)) {
          await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
          return true;
        }
      }
    } catch (e) {
      debugPrint("⭐ [AppReview] Error opening store listing: $e");
    }
    return false;
  }

  static Future<void> _recordPrompt(SharedPreferences prefs) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final count = (prefs.getInt(_prefPromptCountKey) ?? 0) + 1;
    await prefs.setInt(_prefLastPromptKey, now);
    await prefs.setInt(_prefPromptCountKey, count);
  }
}
