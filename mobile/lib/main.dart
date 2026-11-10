import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'content/text_store.dart';
import 'core/app_info.dart';
import 'core/theme.dart';
import 'l10n/localization.dart';
import 'library/audio_download_queue.dart';
import 'library/media_library.dart';
import 'library/music_controller.dart';
import 'library/music_store.dart';
import 'playback/music_handler.dart';
import 'features/library_screen.dart';

const _share = MethodChannel('musicapp/share');

Future<Locale> _readDeviceLocale() async =>
    (await _share.invokeMethod<String>('getDeviceLanguage')) == 'pt'
    ? const Locale('pt')
    : const Locale('en');

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
  var language = AppLanguage.system;
  Locale? deviceLocale;
  try {
    language = AppLanguage.fromPreference(
      await _share.invokeMethod<String>('getLanguage'),
    );
    deviceLocale = await _readDeviceLocale();
    final strings = lookupAppLocalizations(language.locale ?? deviceLocale);
    final handler = await AudioService.init<MusicHandler>(
      builder: () => MusicHandler(strings: strings),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.musicapp.music_app.playback',
        androidNotificationChannelName: strings.playbackChannel,
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
      language: language,
      persistLanguage: (value) =>
          _share.invokeMethod<void>('setLanguage', value.name),
      downloads: TextStore(
        Directory(p.join(p.dirname(store.db.path), 'downloads-v1')),
      ),
    );
    final audioQueue = AudioDownloadQueue(
      historyFile: File(
        p.join(p.dirname(store.db.path), 'audio-downloads-v1.json'),
      ),
      refreshLibrary: () async {
        if (controller.initialized) await controller.refreshAfterMediaChange();
      },
    );
    await audioQueue.initialize();
    final downloadsPage = ValueNotifier<int>(0);
    _share.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'enqueueShared':
          return audioQueue.enqueueShared(call.arguments as String);
        case 'openDownloads':
          downloadsPage.value++;
      }
    });
    runApp(
      MusicApp(
        controller: controller,
        audioQueue: audioQueue,
        downloadsPage: downloadsPage,
        deviceLocale: deviceLocale,
        readDeviceLocale: _readDeviceLocale,
      ),
    );
    await _share.invokeMethod<void>('ready');
  } catch (_) {
    runApp(
      MaterialApp(
        theme: buildTheme(),
        locale: language.locale ?? deviceLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        localeListResolutionCallback: (locales, _) =>
            resolveAppLocale(locales?.firstOrNull),
        home: Builder(
          builder: (context) => Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.l10n.startupFailed(appName),
                    textAlign: TextAlign.center,
                  ),
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
  const MusicApp({
    super.key,
    required this.controller,
    this.audioQueue,
    this.downloadsPage,
    this.deviceLocale,
    this.readDeviceLocale,
  });
  final MusicController controller;
  final AudioDownloadQueue? audioQueue;
  final ValueNotifier<int>? downloadsPage;
  final Locale? deviceLocale;
  final Future<Locale> Function()? readDeviceLocale;
  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  bool midnight = false;
  late AppLanguage language = widget.controller.language;
  late Locale? _deviceLocale = widget.deviceLocale;

  void _appearanceChanged() {
    final state = widget.controller;
    if (state.midnightTheme == midnight && state.language == language) return;
    setState(() {
      midnight = state.midnightTheme;
      language = state.language;
    });
    _updatePlaybackLanguage();
  }

  void _updatePlaybackLanguage([Locale? primary]) {
    if (widget.controller.handler case final MusicHandler handler) {
      handler.setLocale(
        language.locale ??
            _deviceLocale ??
            resolveAppLocale(
              primary ?? WidgetsBinding.instance.platformDispatcher.locale,
            ),
      );
    }
  }

  Future<void> _refreshDeviceLocale() async {
    final read = widget.readDeviceLocale;
    if (read == null) return;
    final locale = await read();
    if (!mounted || locale == _deviceLocale) return;
    setState(() => _deviceLocale = locale);
    _updatePlaybackLanguage();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (widget.readDeviceLocale != null) {
      unawaited(_refreshDeviceLocale());
    } else {
      _updatePlaybackLanguage(locales?.firstOrNull);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    midnight = widget.controller.midnightTheme;
    widget.controller.addListener(_appearanceChanged);
    widget.downloadsPage?.addListener(_showDownloads);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.controller.initialized) {
        unawaited(widget.controller.initialize());
      }
    });
  }

  void _showDownloads() {
    _navigator.currentState?.popUntil((route) => route.isFirst);
    setState(() {});
  }

  @override
  void didUpdateWidget(MusicApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.downloadsPage != widget.downloadsPage) {
      oldWidget.downloadsPage?.removeListener(_showDownloads);
      widget.downloadsPage?.addListener(_showDownloads);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_appearanceChanged);
      midnight = widget.controller.midnightTheme;
      language = widget.controller.language;
      widget.controller.addListener(_appearanceChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.downloadsPage?.removeListener(_showDownloads);
    widget.controller.removeListener(_appearanceChanged);
    widget.audioQueue?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshDeviceLocale());
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
      locale: language.locale ?? _deviceLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeListResolutionCallback: (locales, _) =>
          resolveAppLocale(locales?.firstOrNull),
      home: LibraryScreen(
        key: ValueKey(widget.downloadsPage?.value),
        audioQueue: widget.audioQueue,
        openDownloads: (widget.downloadsPage?.value ?? 0) > 0,
      ),
    ),
  );
}
