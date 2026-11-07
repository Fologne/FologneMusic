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
        title: const Text('Endereço do servidor'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: value,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'URL da API'),
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
                return 'Informe uma URL válida ${kReleaseMode ? 'HTTPS' : 'HTTP ou HTTPS'}.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, value);
            },
            child: const Text('Salvar'),
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
      appBar: AppBar(title: const Text('Configurações')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SectionTitle('Aparência'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(
                Icons.dark_mode_outlined,
                color: AppColors.accent,
              ),
              title: const Text('Tema mais escuro'),
              subtitle: Text(
                state.midnightTheme
                    ? 'Preto com detalhes em azul'
                    : 'Azul-marinho e preto',
              ),
              value: state.midnightTheme,
              onChanged: (value) => state.setAppearance(midnight: value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Capa no fundo'),
              subtitle: const Text('Player e detalhes da playlist'),
              value: state.coverBackground,
              onChanged: (value) => state.setAppearance(showCover: value),
            ),
            Text('Tamanho do texto · ${state.readingSize.round()}'),
            Slider(
              value: state.readingSize,
              min: 16,
              max: 28,
              divisions: 6,
              label: '${state.readingSize.round()}',
              semanticFormatterCallback: (value) =>
                  'Tamanho do texto ${value.round()}',
              onChanged: (value) => state.setAppearance(fontSize: value),
            ),
            const Divider(),
            if (state.downloads case final TextStore store)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_outlined),
                title: const Text('Textos salvos'),
                subtitle: const Text('Espaço usado e leitura offline'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DownloadsScreen(store: store),
                  ),
                ),
              ),
            const SectionTitle('Biblioteca local'),
            const Text(
              'As músicas são lidas do celular. Playlists, favoritos, histórico, fila e textos baixados ficam salvos neste aparelho.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            const Text('$appName $appVersion'),
            TextButton.icon(
              onPressed: () => MusicScope.of(context).media.openSettings(),
              icon: const Icon(Icons.settings),
              label: const Text('Permissões do aplicativo'),
            ),
            TextButton.icon(
              onPressed: () async {
                final state = MusicScope.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Limpar histórico?'),
                    content: const Text(
                      'Favoritos e playlists serão mantidos.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Limpar'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) await state.clearHistory();
              },
              icon: const Icon(Icons.history),
              label: const Text('Limpar histórico'),
            ),
            TextButton.icon(
              onPressed: () => MusicScope.of(context).handler.stop(),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Encerrar reprodução'),
            ),
            const Divider(height: 40),
            const SectionTitle('Busca de textos'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Usar servidor Django'),
              subtitle: Text(
                state.useDjango
                    ? 'Busca pela API configurada'
                    : 'Busca direta pela internet do celular',
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
                  label: const Text('Alterar endereço'),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Text(switch (status) {
                  ConnectionStatus.idle => 'Conexão ainda não verificada',
                  ConnectionStatus.loading => 'Verificando conexão…',
                  ConnectionStatus.online => 'Servidor conectado',
                  ConnectionStatus.offline =>
                    'Servidor indisponível ou sem conexão',
                  ConnectionStatus.error => 'Resposta inválida do servidor',
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
                label: const Text('Verificar conexão'),
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
        title: const Text('Remover textos salvos?'),
        content: Text(entry.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
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
          const SnackBar(content: Text('Não foi possível remover os textos.')),
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
    appBar: AppBar(title: const Text('Textos salvos')),
    body: AppBackground(
      child: FutureBuilder<List<SavedTrackTexts>>(
        future: entries,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível ler o armazenamento.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          final used = items.fold(0, (total, item) => total + item.bytes);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SectionTitle('${_size(used)} de ${_size(widget.store.maxBytes)}'),
              if (items.isEmpty)
                const Text(
                  'Nenhum texto salvo. Use Salvar offline no player quando a fonte permitir.',
                ),
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.title),
                  subtitle: Text(
                    [
                      if (item.artist.isNotEmpty) item.artist,
                      ...item.kinds.map((kind) => kind.label),
                      _size(item.bytes),
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: 'Remover textos de ${item.title}',
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
