// Qyra (user app): a full-screen window onto https://hm5891.github.io/qyra/
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  final tts = FlutterTts();
  String? lastLang;

  Future<void> say(String text, String lang) async {
    try {
      await tts.stop();
      if (lang != lastLang) {
        String use = 'en-US';
        for (final l in [lang, lang.split('-').first]) {
          if (await tts.isLanguageAvailable(l) == true) {
            use = l;
            break;
          }
        }
        await tts.setLanguage(use);
        lastLang = lang;
      }
      await tts.speak(text);
    } catch (_) {}
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    tts.setSpeechRate(0.48);
    tts.setPitch(1.1);
    c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(bg)
      ..addJavaScriptChannel('QyraVoice', onMessageReceived: (m) {
        try {
          final d = jsonDecode(m.message);
          if (d is Map && d['stop'] == true) {
            tts.stop();
          } else if (d is Map && d['say'] is String) {
            say(d['say'] as String, (d['lang'] as String?) ?? 'en-US');
          }
        } catch (_) {}
      })
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
