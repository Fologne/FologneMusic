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
    runApp(MusicApp(controller: controller));
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
  const MusicApp({super.key, required this.controller});
  final MusicController controller;
  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> with WidgetsBindingObserver {
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
    widget.controller.removeListener(_appearanceChanged);
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
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(midnight: midnight),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const LibraryScreen(),
    ),
  );
}
