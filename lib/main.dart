import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'app_config.dart';
import 'services/app_review_service.dart';
import 'services/app_update_service.dart';
import 'widgets/app_rating_dialog.dart';
import 'widgets/app_update_dialog.dart';

FirebaseAnalytics? get analytics {
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      return FirebaseAnalytics.instance;
    }
  } catch (_) {}
  return null;
}

final StreamController<String?> selectNotificationStream = StreamController<String?>.broadcast();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  if (notificationResponse.payload != null) {
    selectNotificationStream.add(notificationResponse.payload);
  }
}

Future<String?> _downloadAndSaveFile(String url, String fileName) async {
  try {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  } catch (e) {
    debugPrint("Error downloading image: $e");
    return null;
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  await Firebase.initializeApp();
  
  if (message.notification == null && message.data.isNotEmpty) {
    final String? title = message.data['title'];
    final String? body = message.data['body'] ?? message.data['message'];
    final String? link = message.data['link'] ?? message.data['url'];
    final String? imageUrl = message.data['image'];
    
    if (title != null || body != null) {
      const initializationSettings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/launcher_icon'));
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) selectNotificationStream.add(response.payload);
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      
      BigPictureStyleInformation? bigPictureStyleInformation;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final String? largeIconPath = await _downloadAndSaveFile(imageUrl, 'notification_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
        if (largeIconPath != null) {
          bigPictureStyleInformation = BigPictureStyleInformation(
            FilePathAndroidBitmap(largeIconPath),
            hideExpandedLargeIcon: true,
            contentTitle: title,
            summaryText: body,
          );
        }
      }
      
      await flutterLocalNotificationsPlugin.show(
        message.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
            styleInformation: bigPictureStyleInformation,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: link,
      );
    }
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      const initializationSettings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/launcher_icon'));
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) selectNotificationStream.add(response.payload);
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      
      if (Platform.isAndroid) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(const AndroidNotificationChannel(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
            ));
      }
    } catch (e) {
      debugPrint("Firebase initialization error: $e");
    }

    // Set status bar style for better visibility on dark backgrounds
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // White icons for dark theme
      statusBarBrightness: Brightness.dark,      // For iOS
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APEPS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF673AB7)),
        useMaterial3: true,
      ),
      home: const WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});
  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? webViewController;
  PullToRefreshController? pullToRefreshController;
  double progress = 0;
  String? fcmToken;
  bool isConnected = true;
  late StreamSubscription<List<ConnectivityResult>> connectivitySubscription;

  final String initialUrl = AppConfig.webUrl;
  String? pendingNotificationUrl;

  @override
  void initState() {
    super.initState();
    debugPrint("🌐 [AppConfig] Active Web URL: ${AppConfig.webUrl} (Local dev: ${AppConfig.useLocalUrl})");
    _checkConnectivity();
    _requestPermissions();
    _setupFCM();
    _handleInitialMessage();
    _initPullToRefresh();
    
    connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      setState(() {
        isConnected = results.isNotEmpty && results.first != ConnectivityResult.none;
      });
      if (isConnected) webViewController?.reload();
    });

    selectNotificationStream.stream.listen((String? payload) {
      if (payload != null && payload.isNotEmpty) {
        analytics?.logEvent(
          name: 'notification_open',
          parameters: {'link': payload},
        );
        _handleLink(payload);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForAppUpdate();
    });
  }

  void _showUpdateDialogIfMounted() {
    if (mounted) {
      AppUpdateDialog.show(context);
    }
  }

  void _showRatingDialogIfMounted() {
    if (mounted) {
      AppRatingDialog.show(context);
    }
  }

  Future<void> _checkForAppUpdate() async {
    final result = await AppUpdateService.checkForUpdate();
    if (result.status == CustomUpdateStatus.updateAvailable) {
      _showUpdateDialogIfMounted();
    }
  }

  Future<void> _handleInitialMessage() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleFCMMessage(initialMessage);
      }
    } catch (_) {}
  }

  void _handleFCMMessage(RemoteMessage message) {
    analytics?.logEvent(
      name: 'notification_open',
      parameters: {
        'message_id': message.messageId ?? '',
        'title': message.notification?.title ?? message.data['title'] ?? '',
      },
    );
    final String? link = message.data['link'] ?? message.data['url'];
    if (link != null && link.isNotEmpty) {
      _handleLink(link);
    }
  }

  void _handleLink(String link) {
    if (link.trim().isEmpty) return;
    debugPrint("🔗 [Notification] Received link to navigate: $link");

    String targetUrl = link.trim();
    if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
      final String cleanPath = targetUrl.startsWith('/') ? targetUrl : '/$targetUrl';
      targetUrl = '${AppConfig.webUrl}$cleanPath';
    }

    debugPrint("🌐 [Notification] Navigating webview to: $targetUrl");
    if (webViewController != null) {
      webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(targetUrl)));
    } else {
      pendingNotificationUrl = targetUrl;
    }
  }

  void _initPullToRefresh() {
    pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: const Color(0xFF673AB7)),
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController?.reload();
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(urlRequest: URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );
  }

  @override
  void dispose() {
    connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final List<ConnectivityResult> results = await Connectivity().checkConnectivity();
    setState(() {
      isConnected = results.isNotEmpty && results.first != ConnectivityResult.none;
    });
  }

  Future<void> _setupFCM() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      debugPrint("📱 [FCM] Notification authorization status: ${settings.authorizationStatus}");

      // Always fetch the FCM token regardless of authorization status
      fcmToken = await messaging.getToken();
      debugPrint("📱 [FCM] Native Token: $fcmToken");

      // Sync token immediately to webview if already loaded
      _syncFCMToken();

      // Listen for live token refreshes from Firebase / Play Services
      messaging.onTokenRefresh.listen((String newToken) {
        fcmToken = newToken;
        debugPrint("🔄 [FCM] Token Refreshed: $newToken");
        _syncFCMToken();
      });
      
      // Subscribe to global and mobile topics for broadcast notifications
      await messaging.subscribeToTopic('all_users');
      await messaging.subscribeToTopic('mobile_users');
      debugPrint("Subscribed to global notifications topics: all_users, mobile_users");

        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleFCMMessage(message);
        });

        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
          final String? title = message.notification?.title ?? message.data['title'];
          final String? body = message.notification?.body ?? message.data['body'] ?? message.data['message'];
          final String? link = message.data['link'] ?? message.data['url'];
          final String? imageUrl = message.notification?.android?.imageUrl ?? message.notification?.apple?.imageUrl ?? message.data['image'] ?? message.data['imageUrl'];
          
          // When app is in foreground and this is a group chat message,
          // the WebView already handles the real-time chat sync and sound.
          // Skip showing a duplicate local notification banner over the user's screen.
          if (message.data['type'] == 'group_chat') {
            return;
          }
          
          if (title != null || body != null) {
            BigPictureStyleInformation? bigPictureStyleInformation;
            if (imageUrl != null && imageUrl.isNotEmpty) {
              final String? largeIconPath = await _downloadAndSaveFile(imageUrl, 'notification_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
              if (largeIconPath != null) {
                bigPictureStyleInformation = BigPictureStyleInformation(
                  FilePathAndroidBitmap(largeIconPath),
                  hideExpandedLargeIcon: true,
                  contentTitle: title,
                  summaryText: body,
                );
              }
            }
            
            flutterLocalNotificationsPlugin.show(
              message.hashCode,
              title,
              body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  'high_importance_channel',
                  'High Importance Notifications',
                  importance: Importance.max,
                  priority: Priority.high,
                  styleInformation: bigPictureStyleInformation,
                ),
                iOS: const DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              payload: link,
            );
          }
        });
    } catch (e) {
      debugPrint("FCM error: $e");
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await [Permission.camera, Permission.microphone, Permission.notification].request();
    }
  }

  // Google blocks its OAuth consent screen inside embedded WebViews, so the
  // web page's normal signInWithPopup can't work here. Instead the page calls
  // this native handler, which uses Android's real account picker and hands
  // back a Firebase ID token the web page can send to the backend exactly
  // like it does after a successful web popup login.
  Future<Map<String, dynamic>> _handleNativeGoogleSignIn() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        return {'success': false, 'error': 'cancelled'};
      }
      final GoogleSignInAuthentication googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) {
        return {'success': false, 'error': 'no_id_token'};
      }
      return {'success': true, 'idToken': idToken};
    } catch (e) {
      debugPrint("Native Google Sign-In error: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<PermissionResponse> _handleWebViewPermissionRequest(PermissionRequest request) async {
    final List<PermissionResourceType> grantedResources = [];
    bool anyPermanentlyDenied = false;

    for (final resource in request.resources) {
      Permission? nativePermission;
      if (resource == PermissionResourceType.CAMERA) {
        nativePermission = Permission.camera;
      } else if (resource == PermissionResourceType.MICROPHONE) {
        nativePermission = Permission.microphone;
      }

      if (nativePermission == null) {
        // Resource we don't gate natively (e.g. protected media id); allow it.
        grantedResources.add(resource);
        continue;
      }

      PermissionStatus status = await nativePermission.status;
      if (!status.isGranted && !status.isPermanentlyDenied) {
        status = await nativePermission.request();
      }
      if (status.isGranted) {
        grantedResources.add(resource);
      } else if (status.isPermanentlyDenied) {
        anyPermanentlyDenied = true;
      }
    }

    if (anyPermanentlyDenied && mounted) {
      _showPermissionSettingsPrompt();
    }

    return PermissionResponse(
      resources: grantedResources,
      action: grantedResources.length == request.resources.length
          ? PermissionResponseAction.GRANT
          : PermissionResponseAction.DENY,
    );
  }

  void _showPermissionSettingsPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Permission Needed"),
        content: const Text(
          "Camera or microphone access is blocked for this app. Please enable it from Settings to record.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await webViewController?.canGoBack() ?? false) {
          webViewController?.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  useShouldOverrideUrlLoading: true,
                  useOnDownloadStart: true,
                  allowFileAccessFromFileURLs: true,
                  allowUniversalAccessFromFileURLs: true,
                  allowFileAccess: true,
                  allowContentAccess: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  geolocationEnabled: true,
                  useOnLoadResource: true,
                  userAgent: "Mozilla/5.0 (Linux; Android 10; APEPS_APP_WRAPPER) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36",
                  transparentBackground: true,
                  supportMultipleWindows: true,
                  allowsBackForwardNavigationGestures: true,
                  overScrollMode: OverScrollMode.IF_CONTENT_SCROLLS,
                  isInspectable: true,
                ),
                pullToRefreshController: pullToRefreshController,
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  var uri = navigationAction.request.url;
                  if (uri != null && uri.toString().contains("external_pay=true")) {
                    debugPrint("🔗 External payment detected, launching system browser: $uri");
                    if (await canLaunchUrl(Uri.parse(uri.toString()))) {
                      await launchUrl(Uri.parse(uri.toString()), mode: LaunchMode.externalApplication);
                    }
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                onWebViewCreated: (controller) {
                  webViewController = controller;
                  controller.addJavaScriptHandler(
                    handlerName: 'nativeGoogleSignIn',
                    callback: (args) async {
                      return await _handleNativeGoogleSignIn();
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'getNativeFCMToken',
                    callback: (args) {
                      return fcmToken;
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'requestAppRating',
                    callback: (args) async {
                      _showRatingDialogIfMounted();
                      return {'success': true};
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'openPlayStoreRating',
                    callback: (args) async {
                      return await AppReviewService.openStoreListing();
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'checkAppUpdate',
                    callback: (args) async {
                      final result = await AppUpdateService.checkForUpdate();
                      final isAvailable = result.status == CustomUpdateStatus.updateAvailable;
                      if (isAvailable) {
                        _showUpdateDialogIfMounted();
                      }
                      return {
                        'updateAvailable': isAvailable,
                        'status': result.status.toString(),
                      };
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'triggerAppUpdate',
                    callback: (args) async {
                      _showUpdateDialogIfMounted();
                      return {'success': true};
                    },
                  );
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    progress = 0;
                  });
                },
                onLoadStop: (controller, url) async {
                  pullToRefreshController?.endRefreshing();
                  setState(() {
                    progress = 1.0;
                  });
                  _syncFCMToken();
                  if (pendingNotificationUrl != null) {
                    final String navUrl = pendingNotificationUrl!;
                    pendingNotificationUrl = null;
                    debugPrint("🚀 [Notification] Loading pending notification URL: $navUrl");
                    controller.loadUrl(urlRequest: URLRequest(url: WebUri(navUrl)));
                  }
                },
                onProgressChanged: (controller, p) {
                  if (p == 100) {
                    pullToRefreshController?.endRefreshing();
                  }
                  setState(() {
                    progress = p / 100;
                  });
                },
                onCreateWindow: (controller, createWindowAction) async {
                  _showPopupDialog(createWindowAction.request.url);
                  return true;
                },
                onPermissionRequest: (controller, request) async {
                  return await _handleWebViewPermissionRequest(request);
                },
              ),
              
              // Browser-style thin progress bar at the top
              if (progress < 1.0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 2.5,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.transparent,
                      color: const Color(0xFF673AB7),
                      minHeight: 2.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPopupDialog(WebUri? url) {
    if (url == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: url),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  userAgent: "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36",
                ),
                onLoadStop: (controller, url) {
                  if (AppConfig.isAppDomain(url.toString())) {
                    Navigator.pop(context);
                    webViewController?.reload();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncFCMToken() async {
    if (webViewController != null) {
      debugPrint("📡 [FCM/Bridge] Syncing native app bridge to webview...");
      await webViewController?.evaluateJavascript(
        source: """
          try {
            if ('$fcmToken' !== 'null' && '$fcmToken' !== '') {
              localStorage.setItem('apeps_flutter_fcm_token', '$fcmToken');
              localStorage.setItem('ssb_flutter_fcm_token', '$fcmToken');
            }
            localStorage.setItem('is_flutter_wrapper', 'true');
            if (typeof window.registerFlutterFCMToken === 'function' && '$fcmToken' !== 'null') {
              window.registerFlutterFCMToken('$fcmToken');
            }
            window.requestAppRating = function() {
              if (window.flutter_inappwebview) {
                return window.flutter_inappwebview.callHandler('requestAppRating');
              }
            };
            window.checkAppUpdate = function() {
              if (window.flutter_inappwebview) {
                return window.flutter_inappwebview.callHandler('checkAppUpdate');
              }
            };
            if (navigator.mediaDevices) {
              navigator.mediaDevices.getDisplayMedia = function() {
                return Promise.reject(new DOMException("Screen recording is disabled for privacy and security.", "NotAllowedError"));
              };
            }
          } catch(e) { console.error('App bridge error:', e); }
        """,
      );
    }
  }
}
