import '../l10n/localization.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../content/text_store.dart';
import '../core/app_info.dart';
import '../core/health_api.dart';
import '../core/theme.dart';
import '../library/music_controller.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.api});
  final HealthApi? api;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ConnectionStatus status = ConnectionStatus.idle;

  Future<void> check(HealthApi api) async {
    setState(() => status = ConnectionStatus.loading);
    final result = await api.check();
    if (mounted) setState(() => status = result);
  }

  Future<void> _editServer(MusicController state) async {
    final form = GlobalKey<FormState>();
    var value = state.apiBaseUrl;
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.serverAddress),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: value,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: context.l10n.apiUrl),
            onChanged: (text) => value = text.trim(),
            validator: (_) {
              final uri = Uri.tryParse(value);
              if (uri == null ||
                  uri.host.isEmpty ||
                  uri.hasQuery ||
                  uri.hasFragment ||
                  uri.userInfo.isNotEmpty ||
                  !(uri.scheme == 'https' ||
                      (!kReleaseMode && uri.scheme == 'http'))) {
                return context.l10n.invalidApiUrl(
                  kReleaseMode ? 'HTTPS' : 'HTTP ou HTTPS',
                );
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, value);
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    if (!mounted || url == null) return;
    await state.setApiBaseUrl(url);
    if (mounted) setState(() => status = ConnectionStatus.idle);
  }

  @override
  Widget build(BuildContext context) {
    final state = MusicScope.of(context);
    final api = widget.api ?? HealthApi(baseUrl: state.apiBaseUrl);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language),
              title: Text(context.l10n.appLanguage),
              trailing: DropdownButton<AppLanguage>(
                value: state.language,
                items: [
                  DropdownMenuItem(
                    value: AppLanguage.system,
                    child: Text(context.l10n.systemLanguage),
                  ),
                  const DropdownMenuItem(
                    value: AppLanguage.pt,
                    child: Text('Português'),
                  ),
                  const DropdownMenuItem(
                    value: AppLanguage.en,
                    child: Text('English'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) state.setLanguage(value);
                },
              ),
            ),
            SectionTitle(context.l10n.appearance),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(
                Icons.dark_mode_outlined,
                color: AppColors.accent,
              ),
              title: Text(context.l10n.darkerTheme),
              subtitle: Text(
                state.midnightTheme
                    ? context.l10n.blackWithBlueAccents
                    : context.l10n.navyBlueAndBlack,
              ),
              value: state.midnightTheme,
              onChanged: (value) => state.setAppearance(midnight: value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.coverArtBackground),
              subtitle: Text(context.l10n.playerAndPlaylistDetails),
              value: state.coverBackground,
              onChanged: (value) => state.setAppearance(showCover: value),
            ),
            Text(context.l10n.textSize(state.readingSize.round())),
            Slider(
              value: state.readingSize,
              min: 16,
              max: 28,
              divisions: 6,
              label: '${state.readingSize.round()}',
              semanticFormatterCallback: (value) =>
                  context.l10n.textSizeAccessibility(value.round()),
              onChanged: (value) => state.setAppearance(fontSize: value),
            ),
            const Divider(),
            if (state.downloads case final TextStore store)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_outlined),
                title: Text(context.l10n.savedTexts),
                subtitle: Text(context.l10n.storageUsedAndOfflineReading),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DownloadsScreen(store: store),
                  ),
                ),
              ),
            SectionTitle(context.l10n.localLibrary),
            Text(
              context.l10n.localStorageNotice,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            const Text('$appName $appVersion'),
            TextButton.icon(
              onPressed: () => MusicScope.of(context).media.openSettings(),
              icon: const Icon(Icons.settings),
              label: Text(context.l10n.appPermissions),
            ),
            TextButton.icon(
              onPressed: () async {
                final state = MusicScope.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(context.l10n.clearListeningHistory),
                    content: Text(context.l10n.clearListeningHistoryNotice),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.l10n.clear),
                      ),
                    ],
                  ),
                );
                if (confirm == true) await state.clearHistory();
              },
              icon: const Icon(Icons.history),
              label: Text(context.l10n.clearHistory),
            ),
            TextButton.icon(
              onPressed: () => MusicScope.of(context).handler.stop(),
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(context.l10n.stopPlayback),
            ),
            const Divider(height: 40),
            SectionTitle(context.l10n.textSearch),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.useDjangoServer),
              subtitle: Text(
                state.useDjango
                    ? context.l10n.djangoSearchDescription
                    : context.l10n.directSearchDescription,
              ),
              value: state.useDjango,
              onChanged: status == ConnectionStatus.loading
                  ? null
                  : (enabled) {
                      if (enabled && state.apiBaseUrl.isEmpty) {
                        _editServer(state);
                      } else {
                        state.setDjangoMode(enabled);
                        setState(() => status = ConnectionStatus.idle);
                      }
                    },
            ),
            if (state.useDjango || widget.api != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                api.baseUrl,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: status == ConnectionStatus.loading
                      ? null
                      : () => _editServer(state),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.l10n.changeAddress),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Text(switch (status) {
                  ConnectionStatus.idle => context.l10n.connectionUnchecked,
                  ConnectionStatus.loading => context.l10n.checkingConnection,
                  ConnectionStatus.online => context.l10n.serverConnected,
                  ConnectionStatus.offline =>
                    context.l10n.serverUnavailableOrNoConnection,
                  ConnectionStatus.error => context.l10n.invalidServerResponse,
                }, key: const Key('connection-status')),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('check-connection'),
                onPressed: status == ConnectionStatus.loading
                    ? null
                    : () => check(api),
                icon: status == ConnectionStatus.loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(context.l10n.checkConnection),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key, required this.store});
  final TextStore store;

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late Future<List<SavedTrackTexts>> entries = widget.store.entries();

  Future<void> _remove(SavedTrackTexts entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.removeSavedTexts),
        content: Text(entry.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.remove),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await widget.store.remove(entry.key);
      if (mounted) setState(() => entries = widget.store.entries());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.savedTextRemoveFailed)),
        );
      }
    }
  }

  String _size(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KiB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.savedTexts)),
    body: AppBackground(
      child: FutureBuilder<List<SavedTrackTexts>>(
        future: entries,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(context.l10n.storageReadFailed));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          final used = items.fold(0, (total, item) => total + item.bytes);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SectionTitle(
                context.l10n.storageUsage(
                  _size(used),
                  _size(widget.store.maxBytes),
                ),
              ),
              if (items.isEmpty) Text(context.l10n.emptySavedTextsHint),
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.title),
                  subtitle: Text(
                    [
                      if (item.artist.isNotEmpty)
                        context.localizedMessage(item.artist),
                      ...item.kinds.map(context.textKindLabel),
                      _size(item.bytes),
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: context.l10n.removeTextsFor(item.title),
                    onPressed: () => _remove(item),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
