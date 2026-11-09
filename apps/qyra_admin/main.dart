// Qyra Admin: a full-screen window onto https://hm5891.github.io/qyra/admin.html
// Adds what a plain WebView lacks: picking photos from the phone and copying prompts.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const adminUrl = 'https://hm5891.github.io/qyra/admin.html';
const bg = Color(0xFFF6F3F7);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: bg, statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.dark));
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, title: 'Qyra Admin', home: Shell()));
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late final WebViewController c;
  bool offline = false;

  @override
  void initState() {
    super.initState();
    c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(bg)
      ..addJavaScriptChannel('QyraNative', onMessageReceived: (m) {
        try {
          final d = jsonDecode(m.message);
          if (d is Map && d['copy'] is String) {
            Clipboard.setData(ClipboardData(text: d['copy'] as String));
          }
        } catch (_) {}
      })
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) setState(() => offline = true);
        },
      ));
    final p = c.platform;
    if (p is AndroidWebViewController) {
      p.setOnShowFileSelector((params) async {
        final wantsImage = params.acceptTypes.isEmpty || params.acceptTypes.any((t) => t.startsWith('image'));
        if (!wantsImage) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Restore a backup from Chrome: open hm5891.github.io/qyra/admin.html')));
          return <String>[];
        }
        final x = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (x == null) return <String>[];
        return <String>[Uri.file(x.path).toString()];
      });
    }
    c.clearCache().whenComplete(() => c.loadRequest(Uri.parse(adminUrl)));
  }

  void retry() {
    setState(() => offline = false);
    c.loadRequest(Uri.parse(adminUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await c.canGoBack()) {
          c.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: offline
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('No internet connection',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    FilledButton(onPressed: retry, child: const Text('Try again')),
                  ]),
                )
              : WebViewWidget(controller: c),
        ),
      ),
    );
  }
}
