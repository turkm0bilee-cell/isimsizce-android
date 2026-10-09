import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(const IsimsizceApp());

class IsimsizceApp extends StatelessWidget {
  const IsimsizceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'İsimsizce',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF141625),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFA575FA), brightness: Brightness.dark),
      useMaterial3: true,
    ),
    home: const SitePage(),
  );
}

class SitePage extends StatefulWidget {
  const SitePage({super.key});
  @override
  State<SitePage> createState() => _SitePageState();
}

class _SitePageState extends State<SitePage> {
  static final home = Uri.parse('https://isimsizce.net/index.php');
  late final WebViewController controller;
  int progress = 0;
  bool failed = false;
  bool goingBack = false;
  bool refreshing = false;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF141625))
      ..addJavaScriptChannel('IsimsizceRefresh', onMessageReceived: (message) async {
        if (message.message != 'refresh' || refreshing || progress < 100) return;
        final current = Uri.tryParse(await controller.currentUrl() ?? '');
        if (!mounted || current?.scheme != 'https' || current?.host != home.host) return;
        refreshing = true;
        try { await controller.reload(); }
        catch (_) { refreshing = false; }
      })
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (value) { if (mounted) setState(() => progress = value); },
        onPageStarted: (_) {
          if (mounted) setState(() { failed = false; progress = 0; });
        },
        onPageFinished: (_) async {
          try { await controller.runJavaScript(mobileAdjustments); await controller.runJavaScript(pullRefresh); }
          catch (_) { /* The website remains usable if its markup changes. */ }
          refreshing = false;
          if (mounted) setState(() => progress = 100);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            refreshing = false;
            setState(() { failed = true; progress = 100; });
          }
        },
        onNavigationRequest: (request) async {
          final uri = Uri.tryParse(request.url);
          if (uri == null) return NavigationDecision.prevent;
          if (uri.scheme == 'https' && uri.host == home.host) {
            return NavigationDecision.navigate;
          }
          if (request.isMainFrame &&
              ['https', 'http', 'mailto', 'tel'].contains(uri.scheme)) {
            try {
              final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!opened && mounted) _externalError();
            } catch (_) { if (mounted) _externalError(); }
          }
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(home);
  }

  void _externalError() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Bağlantı açılamadı. Lütfen tekrar dene.')));

  Future<void> back({bool exitAtHome = false}) async {
    if (goingBack) return;
    goingBack = true;
    try {
      final closed = await controller.runJavaScriptReturningResult(
        "(() => { const d = document.querySelector('dialog[open]'); "
        "if(d){d.close();return true;}return false;})()");
      if (closed == true || closed == 'true') return;
      if (await controller.canGoBack()) { await controller.goBack(); }
      else if (exitAtHome) { await SystemNavigator.pop(); }
    } finally { goingBack = false; }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) back(exitAtHome: true);
    },
    child: Scaffold(
      body: SafeArea(child: Stack(children: [
        Positioned.fill(child: WebViewWidget(controller: controller)),
        if (progress < 100) Align(alignment: Alignment.topCenter,
          child: LinearProgressIndicator(value: progress / 100)),
        if (failed) Positioned.fill(child: ColoredBox(
          color: const Color(0xFF141625),
          child: Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off_rounded, size: 44),
              const SizedBox(height: 16),
              const Text('Sayfa yüklenemedi. İnternet bağlantını kontrol et.',
                textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: () {
                setState(() { failed = false; progress = 0; });
                controller.reload();
              }, child: const Text('Tekrar dene')),
            ]))),
        )),
      ])),
      bottomNavigationBar: SafeArea(top: false, child: SizedBox(height: 44,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(tooltip: 'Geri', onPressed: back,
            icon: const Icon(Icons.arrow_back_rounded)),
          IconButton(tooltip: 'Ana Sayfa', onPressed: () => controller.loadRequest(home),
            icon: const Icon(Icons.home_outlined)),
          IconButton(tooltip: 'Yenile', onPressed: () => controller.reload(),
            icon: const Icon(Icons.refresh_rounded)),
        ]))),
    ),
  );
}

const mobileAdjustments = r'''(() => {
  document.querySelectorAll('a[href]').forEach(link => {
    try {
      const target = new URL(link.getAttribute('href'), location.href);
      if (target.origin === location.origin && target.pathname === '/android.php') {
        link.remove();
      }
    } catch (_) { /* Ignore malformed links. */ }
  });
  const dialog = document.getElementById('isimsizce-about-dialog');
  if (dialog) {
    dialog.querySelector('.isimsizce-about-test')?.remove();
    const paragraphs = dialog.querySelectorAll(':scope > p');
    if (paragraphs[0]) paragraphs[0].innerHTML = '<strong>İsimsizce</strong>, gerçek adını paylaşmadan fikirlerini, deneyimlerini ve merak ettiklerini konuşabileceğin anonim bir sözlük.';
    if (paragraphs[1]) paragraphs[1].textContent = 'Amacımız, farklı fikirlerin özgürce paylaşıldığı, insanların birbirine ve özel hayatına saygı duyduğu samimi bir ortam oluşturmak.';
  }
  if (!document.getElementById('isimsizce-app-style')) {
    const style = document.createElement('style');
    style.id = 'isimsizce-app-style';
    style.textContent = 'a.post{display:block;width:100%;box-sizing:border-box} .logo-icon{object-fit:contain} #app-pages{display:flex;flex-wrap:wrap;gap:8px;justify-content:center;margin:24px 0} #app-pages button{min-width:44px;min-height:44px;padding:8px 12px;border:1px solid #a575fa;border-radius:10px;background:#22263a;color:#f7f5ff;font:inherit} #app-pages button[aria-current]{background:#7943cd} #app-pages button:disabled{opacity:.45}';
    document.head.appendChild(style);
  }
  // Index already has server-side pages of ten. Paginate only the longer
  // discovery/search lists, preserving the server's ranking and search results.
  const cards = Array.from(document.querySelectorAll('a.post[href*="topic.php?id="]'));
  if (cards.length > 10 && !document.getElementById('app-pages')) {
    const nav = document.createElement('nav');
    nav.id = 'app-pages';
    nav.setAttribute('aria-label', 'Başlık sayfaları');
    cards[cards.length - 1].after(nav);
    let page = 1;
    const pages = Math.ceil(cards.length / 10);
    const render = () => {
      cards.forEach((card, i) => { card.hidden = Math.floor(i / 10) + 1 !== page; card.style.display = card.hidden ? 'none' : ''; });
      nav.replaceChildren();
      const add = (label, target, disabled, current = false) => {
        const button = document.createElement('button');
        button.type = 'button'; button.textContent = label; button.disabled = disabled;
        if (current) button.setAttribute('aria-current', 'page');
        button.onclick = () => { page = target; render(); window.scrollTo({top:0,behavior:'smooth'}); };
        nav.appendChild(button);
      };
      add('← Önceki', page - 1, page === 1);
      for (let i = 1; i <= pages; i++) add(String(i), i, false, page === i);
      add('Sonraki →', page + 1, page === pages);
    };
    render();
  }
})();
''';
const pullRefresh = r'''
// Installed once per document after the WebView finishes loading.
(() => {
  if (window.__isimsizcePullRefresh) return;
  window.__isimsizcePullRefresh = true;
  const threshold = 100;
  let start = null;
  let distance = 0;
  let loading = false;
  const indicator = document.createElement('div');
  indicator.setAttribute('role', 'status');
  indicator.style.cssText = 'position:fixed;top:12px;left:50%;transform:translateX(-50%);z-index:2147483647;padding:10px 16px;border-radius:24px;background:#22263a;color:#f7f5ff;box-shadow:0 2px 12px #0006;font:14px sans-serif;pointer-events:none;display:none';
  document.body.appendChild(indicator);
  const reset = () => {
    start = null;
    distance = 0;
    if (!loading) indicator.style.display = 'none';
  };
  const atTop = () => (document.scrollingElement?.scrollTop ?? window.scrollY) <= 1;
  document.addEventListener('touchstart', event => {
    reset();
    if (loading || event.touches.length !== 1 || !atTop() ||
        document.querySelector('dialog[open]') ||
        event.target.closest('input,textarea,select,button,[contenteditable]:not([contenteditable="false"])') ||
        document.activeElement?.matches('input,textarea,[contenteditable]:not([contenteditable="false"])')) return;
    // Let nested scrollable areas handle their own gestures.
    for (let node = event.target; node && node !== document.body && node !== document.documentElement; node = node.parentElement) {
      if (node.scrollHeight > node.clientHeight + 1 && /auto|scroll/.test(getComputedStyle(node).overflowY)) return;
    }
    const touch = event.touches[0];
    start = {x: touch.clientX, y: touch.clientY};
  }, {passive: true});
  document.addEventListener('touchmove', event => {
    if (!start) return;
    if (event.touches.length !== 1 || !atTop()) { reset(); return; }
    const touch = event.touches[0];
    const dy = touch.clientY - start.y;
    const dx = Math.abs(touch.clientX - start.x);
    if (dy < -8 || (dx > 12 && dx > Math.abs(dy))) { reset(); return; }
    distance = Math.max(0, dy);
    if (distance < 12) { indicator.style.display = 'none'; return; }
    if (!event.cancelable) { reset(); return; }
    event.preventDefault();
    indicator.style.display = 'block';
    indicator.textContent = distance >= threshold ? '↻ Yenilemek için bırak' : '↓ Yenilemek için çek';
  }, {passive: false});
  document.addEventListener('touchend', () => {
    const refresh = start && distance >= threshold && atTop() && !loading;
    reset();
    if (!refresh) return;
    loading = true;
    indicator.style.display = 'block';
    indicator.textContent = '↻ Yenileniyor…';
    IsimsizceRefresh.postMessage('refresh');
  }, {passive: true});
  document.addEventListener('touchcancel', reset, {passive: true});
})();

''';
