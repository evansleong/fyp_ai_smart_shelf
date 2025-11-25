import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ⚠️ IMPORT THIS TO FIX THE ERROR
import 'package:webview_flutter_android/webview_flutter_android.dart';

class FaceLivenessWebView extends StatefulWidget {
  final String sessionId;
  const FaceLivenessWebView({super.key, required this.sessionId});

  @override
  State<FaceLivenessWebView> createState() => _FaceLivenessWebViewState();
}

class _FaceLivenessWebViewState extends State<FaceLivenessWebView> {
  late final WebViewController _controller;
  // REPLACE with your Vercel URL
  final String _bridgeUrl = "https://evansleong.github.io/liveness-bridge";

  @override
  void initState() {
    super.initState();

    // 1. Initialize the Controller
    final WebViewController controller = WebViewController();

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            debugPrint('Page loaded: $url');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'COMPLETE') {
            Navigator.of(context).pop(true); // Success
          } else if (message.message == 'CANCEL') {
            // User clicked the X button in React
            debugPrint("User cancelled liveness check");
            Navigator.of(context).pop();
          } else if (message.message.startsWith('ERROR')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text("Liveness Check Failed: ${message.message}")),
            );
            Navigator.of(context).pop(false);
          }
        },
      )
      ..loadRequest(Uri.parse('$_bridgeUrl?session_id=${widget.sessionId}'));

    // 2. ⚠️ ANDROID SPECIFIC PERMISSIONS LOGIC ⚠️
    // This fixes the "PlatformWebViewController" issue
    if (controller.platform is AndroidWebViewController) {
      // Create a typed variable
      final AndroidWebViewController androidController =
          controller.platform as AndroidWebViewController;

      // Now we can call Android-specific methods
      androidController.setMediaPlaybackRequiresUserGesture(false);

      // Auto-grant camera permissions
      androidController.setOnPlatformPermissionRequest(
        (PlatformWebViewPermissionRequest request) {
          debugPrint("Granting camera permission for type: ${request.types}");
          request.grant();
        },
      );
    }

    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
