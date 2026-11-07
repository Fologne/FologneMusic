import 'package:flutter/material.dart';

import '../content/content_api.dart';
import '../core/theme.dart';
import '../library/media_library.dart';
import '../library/music_controller.dart';
import '../widgets/common.dart';

class ContentTab extends StatefulWidget {
  const ContentTab({super.key, required this.track, required this.kind});
  final Track track;
  final TextKind kind;

  @override
  State<ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends State<ContentTab>
    with AutomaticKeepAliveClientMixin {
  late SearchTrack search = SearchTrack.fromTrack(widget.track);
  TrackText? offline;
  TrackText? online;
  TrackMatch? selected;
  List<TrackMatch> candidates = [];
  String? message;
  bool loading = false;
  bool ready = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!ready) {
      ready = true;
      _readSaved();
    }
  }

  Future<void> _readSaved() async {
    final store = MusicScope.of(context).downloads;
    try {
      final cached = await store?.read(widget.track, widget.kind);
      if (mounted && cached != null) setState(() => offline = cached);
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Não foi possível abrir o texto salvo.');
      }
    }
  }

  Future<void> _lookup() async {
    if (loading) return;
    if (search.artist.isEmpty) {
      await _editSearch();
      return;
    }
    final api = MusicScope.of(context).textLookup;
    setState(() {
      loading = true;
      message = null;
      candidates = [];
    });
    try {
      final resolution = await api.resolve(search, kind: widget.kind);
      if (!mounted) return;
      TrackMatch? match = resolution.match;
      if (widget.kind == TextKind.meaning &&
          resolution.status != 'identity_ambiguous') {
        match ??= resolution.metadata;
      } else if (resolution.candidates.isNotEmpty && match == null) {
        setState(() => candidates = resolution.candidates);
      } else if (match == null) {
        setState(
          () => message = switch (resolution.status) {
            'provider_rate_limited' =>
              'A fonte atingiu o limite. Tente novamente em instantes.',
            'unavailable' => 'A fonte está indisponível no momento.',
            _ => 'Letra não encontrada. Confira o título e o artista da busca.',
          },
        );
      }
      if (match == null || !mounted) return;
      await _fetch(api, match);
    } on ContentFailure catch (error) {
      if (mounted) setState(() => message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Não foi possível ler a resposta do servidor.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _fetch(TextLookup api, TrackMatch match) async {
    final result = await api.fetch(match, widget.kind);
    if (!mounted) return;
    setState(() {
      online = result;
      selected = match;
      candidates = [];
    });
  }

  Future<void> _choose(TrackMatch match) async {
    if (loading) return;
    final api = MusicScope.of(context).textLookup;
    setState(() {
      loading = true;
      message = null;
    });
    try {
      await _fetch(api, match);
    } on ContentFailure catch (error) {
      if (mounted) setState(() => message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Não foi possível ler a resposta do servidor.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _editSearch() async {
    if (loading) return;
    final edited = await showDialog<SearchTrack>(
      context: context,
      builder: (_) => _SearchDialog(search: search),
    );
    if (!mounted || edited == null) return;
    setState(() {
      search = edited;
      online = null;
      selected = null;
    });
    await _lookup();
  }

  Future<void> _download(TrackText text, TrackMatch match) async {
    final store = MusicScope.of(context).downloads;
    if (store == null || loading) return;
    setState(() {
      loading = true;
      message = null;
    });
    try {
      await store.save(widget.track, widget.kind, match.key, text);
      if (mounted) setState(() => offline = text);
    } on ContentFailure catch (error) {
      if (mounted) setState(() => message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Não foi possível salvar o texto neste aparelho.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openSource(Uri uri) async {
    try {
      if (await AndroidMediaLibrary.openSource(uri)) return;
    } catch (_) {}
    if (mounted) setState(() => message = 'Não foi possível abrir o link.');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = MusicScope.of(context);
    final result = online?.status == 'found' ? online : offline ?? online;
    final match = selected;
    final chosenDuration = match?.track.durationMs;
    final timingDiffers =
        widget.track.durationMs > 0 &&
        chosenDuration != null &&
        (widget.track.durationMs - chosenDuration).abs() > 4000;
    final text = result?.readableText ?? '';
    final currentLine = widget.kind == TextKind.lyrics && !timingDiffers
        ? result?.currentLine((settings.position * 1000).round())
        : null;
    final canDownload =
        settings.downloads != null &&
        match != null &&
        result == online &&
        result != offline &&
        (result?.offlineAllowed ?? false);
    final title = widget.kind.label;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Text(widget.track.title, style: Theme.of(context).textTheme.titleLarge),
        Text(
          widget.track.artist,
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: loading ? null : _lookup,
              icon: Icon(result == null ? Icons.search : Icons.refresh),
              label: Text(result == null ? 'Buscar $title' : 'Atualizar busca'),
            ),
            OutlinedButton.icon(
              onPressed: loading ? null : _editSearch,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Corrigir busca'),
            ),
          ],
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LinearProgressIndicator(semanticsLabel: 'Aguarde'),
          ),
        if (offline != null)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.offline_pin_outlined),
            title: Text('Disponível offline'),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(liveRegion: true, child: Text(message!)),
          ),
        if (candidates.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Escolha a gravação'),
          ),
          for (final candidate in candidates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(candidate.track.title),
              subtitle: Text(
                [
                  candidate.track.artist,
                  if (candidate.track.album.isNotEmpty) candidate.track.album,
                  if (candidate.track.durationMs case final int duration)
                    durationLabel(duration / 1000),
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: loading ? null : () => _choose(candidate),
            ),
        ],
        if (result == null && message == null && !loading && candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text('Busque $title na internet usando os dados da faixa.'),
          ),
        if (result != null) ...[
          const SizedBox(height: 16),
          if (result.kind == 'artist_commentary')
            const Text('Comentário do artista resumido'),
          if (result.kind == 'encyclopedic_context')
            const Text('Contexto enciclopédico disponível na fonte.'),
          if (result.kind == 'editorial_context')
            const Text('Interpretação da faixa'),
          if (timingDiffers && widget.kind == TextKind.lyrics)
            const Text(
              'Esta gravação tem outra duração. A letra é exibida sem sincronização.',
            ),
          if (currentLine != null && currentLine.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                currentLine,
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: settings.readingSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (text.isNotEmpty)
            SelectionArea(
              child: Text(
                text,
                style: TextStyle(fontSize: settings.readingSize, height: 1.55),
              ),
            )
          else if (result.status != 'link_only')
            Text(switch (result.status) {
              'instrumental' =>
                'A fonte identifica esta faixa como instrumental.',
              'language_unavailable' =>
                'A fonte não oferece contexto neste idioma.',
              'not_resolved' => 'Escolha a gravação para consultar a letra.',
              _ => '$title não encontrado para esta faixa.',
            }),
          if (offline != null && online != null && online!.status != 'found')
            const Text(
              'A atualização não trouxe outro texto. A cópia salva foi mantida.',
            ),
          if (result.sourceName case final String source)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                [
                  'Fonte: $source',
                  if (result.sourceTitle case final String title) title,
                  'Idioma: ${result.language ?? 'original (não informado pela fonte)'}',
                  if (result.fetchedAt case final DateTime date)
                    'Consulta: ${MaterialLocalizations.of(context).formatCompactDate(date.toLocal())}',
                ].join(' · '),
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          if (result.sourceUrl case final Uri url)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openSource(url),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir fonte'),
              ),
            ),
          if (canDownload)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: loading ? null : () => _download(result, match),
                icon: const Icon(Icons.download_outlined),
                label: Text(
                  offline == null
                      ? 'Salvar offline'
                      : 'Atualizar cópia offline',
                ),
              ),
            )
          else if (result.status == 'found' && !result.offlineAllowed)
            const Text(
              'Esta fonte oferece leitura online. A cópia offline não está disponível.',
            ),
        ],
      ],
    );
  }
}

class _SearchDialog extends StatefulWidget {
  const _SearchDialog({required this.search});
  final SearchTrack search;

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.search.title);
  late final artist = TextEditingController(text: widget.search.artist);
  late final album = TextEditingController(text: widget.search.album);
  bool useDuration = true;

  @override
  void dispose() {
    title.dispose();
    artist.dispose();
    album.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Corrigir busca'),
    scrollable: true,
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (field, controller, required) in [
            ('Título', title, true),
            ('Artista', artist, true),
            ('Álbum', album, false),
          ])
            TextFormField(
              controller: controller,
              maxLength: 240,
              decoration: InputDecoration(labelText: field, counterText: ''),
              validator: (value) => required && (value?.trim().isEmpty ?? true)
                  ? 'Preencha este campo'
                  : null,
            ),
          if (widget.search.durationMs != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Considerar a duração'),
              value: useDuration,
              onChanged: (value) => setState(() => useDuration = value == true),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          Navigator.pop(
            context,
            SearchTrack(
              title.text.trim(),
              artist.text.trim(),
              album.text.trim(),
              useDuration ? widget.search.durationMs : null,
            ),
          );
        },
        child: const Text('Buscar'),
      ),
    ],
  );
}
