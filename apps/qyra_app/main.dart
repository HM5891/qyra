// Qyra (user app): a full-screen window onto https://hm5891.github.io/qyra/
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

const appUrl = 'https://hm5891.github.io/qyra/';
const bg = Color(0xFF0D0A0F);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: bg, statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.light));
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, title: 'Qyra', home: Shell()));
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
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) setState(() => offline = true);
        },
        onNavigationRequest: (r) => r.url.startsWith(appUrl) || r.url.startsWith('about:')
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ));
    c.clearCache().whenComplete(() => c.loadRequest(Uri.parse(appUrl)));
  }

  void retry() {
    setState(() => offline = false);
    c.loadRequest(Uri.parse(appUrl));
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
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
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
