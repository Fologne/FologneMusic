import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path/path.dart' as p;

import 'content/text_store.dart';
import 'core/app_info.dart';
import 'core/theme.dart';
import 'core/youtube_link.dart';
import 'features/audio_downloads_screen.dart';
import 'library/audio_download_queue.dart';
import 'library/media_library.dart';
import 'library/music_controller.dart';
import 'library/music_store.dart';
import 'playback/music_handler.dart';
import 'features/library_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  try {
    final handler = await AudioService.init<MusicHandler>(
      builder: MusicHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.musicapp.music_app.playback',
        androidNotificationChannelName: 'Reprodução de música',
        androidNotificationIcon: 'drawable/ic_music_note',
        artDownscaleWidth: 512,
        artDownscaleHeight: 512,
        androidStopForegroundOnPause: false,
      ),
    );
    await handler.configure();
    final store = await SqliteMusicStore.open();
    final controller = MusicController(
      media: AndroidMediaLibrary(),
      store: store,
      handler: handler,
      downloads: TextStore(
        Directory(p.join(p.dirname(store.db.path), 'downloads-v1')),
      ),
    );
    final audioQueue = AudioDownloadQueue(
      historyFile: File(
        p.join(p.dirname(store.db.path), 'audio-downloads-v1.json'),
      ),
      refreshLibrary: controller.refreshAfterMediaChange,
    );
    await audioQueue.initialize();
    runApp(MusicApp(controller: controller, audioQueue: audioQueue));
    unawaited(controller.initialize());
  } catch (_) {
    runApp(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Não foi possível iniciar o $appName. Feche o aplicativo e tente novamente.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MusicApp extends StatefulWidget {
  const MusicApp({super.key, required this.controller, this.audioQueue});
  final MusicController controller;
  final AudioDownloadQueue? audioQueue;
  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> with WidgetsBindingObserver {
  static const _shareChannel = MethodChannel('musicapp/share');
  final _navigator = GlobalKey<NavigatorState>();
  bool _readingShares = false;
  bool _shareRequested = false;
  bool midnight = false;

  void _appearanceChanged() {
    final value = widget.controller.midnightTheme;
    if (value != midnight) setState(() => midnight = value);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    midnight = widget.controller.midnightTheme;
    widget.controller.addListener(_appearanceChanged);
    if (Platform.isAndroid) {
      _shareChannel.setMethodCallHandler((call) async {
        if (call.method == 'shareAvailable') unawaited(_readSharedLinks());
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_readSharedLinks());
      });
    }
  }

  Future<void> _readSharedLinks() async {
    _shareRequested = true;
    if (_readingShares || _navigator.currentContext == null) return;
    _readingShares = true;
    try {
      while (mounted && _shareRequested) {
        _shareRequested = false;
        final text = await _shareChannel.invokeMethod<String>('takeSharedText');
        if (!mounted || text == null) continue;
        _shareRequested = true;
        await _confirmSharedLink(youtubeVideoLink(text));
      }
    } on PlatformException {
      // Sharing is optional. The library stays available if the channel fails.
    } finally {
      _readingShares = false;
    }
  }

  Future<void> _confirmSharedLink(Uri? link) async {
    final context = _navigator.currentContext;
    if (context == null) return;
    if (link == null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Link inválido'),
          content: const Text('Compartilhe o link de um vídeo do YouTube.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
      return;
    }
    final queue = widget.audioQueue;
    final available = queue?.available == true;
    final confirmed = await confirmDownloadLink(
      context,
      link,
      available: available,
    );
    if (!confirmed || !context.mounted) return;
    final message = !available
        ? 'Link confirmado. O download de áudio está disponível no APK experimental.'
        : queue!.enqueue(link)
        ? 'Adicionado à fila. Acompanhe na aba Downloads.'
        : 'Este link já está na fila ou no histórico.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void didUpdateWidget(MusicApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_appearanceChanged);
      midnight = widget.controller.midnightTheme;
      widget.controller.addListener(_appearanceChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isAndroid) _shareChannel.setMethodCallHandler(null);
    widget.controller.removeListener(_appearanceChanged);
    widget.audioQueue?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.controller.initialized) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.refresh());
    } else {
      unawaited(widget.controller.save());
    }
  }

  @override
  Widget build(BuildContext context) => MusicScope(
    controller: widget.controller,
    child: MaterialApp(
      navigatorKey: _navigator,
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(midnight: midnight),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: LibraryScreen(audioQueue: widget.audioQueue),
    ),
  );
}
