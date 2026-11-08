import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/theme.dart';
import 'package:music_app/features/library_screen.dart';
import 'package:music_app/library/music_controller.dart';
import 'package:music_app/main.dart';
import 'package:music_app/widgets/common.dart';
import 'package:music_app/widgets/playlist_actions.dart';

import 'support/fakes.dart';

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  Future<MusicController> controller({
    bool allowed = true,
    List<Track>? rows,
  }) async {
    final media = FakeMedia()..allowed = allowed;
    if (rows != null) media.rows = rows;
    final state = MusicController(
      media: media,
      store: MemoryStore(),
      handler: FakeHandler(),
    );
    await state.initialize();
    addTearDown(state.dispose);
    return state;
  }

  testWidgets('seletor mostra capas à esquerda e salva na ordem dos toques', (
    tester,
  ) async {
    final state = await controller();
    final playlist = await state.createPlaylist('Teste');
    await tester.pumpWidget(
      MusicScope(
        controller: state,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => pickPlaylistTracks(context, playlist),
                child: const Text('Abrir seletor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir seletor'));
    await tester.pumpAndSettle();
    final first = find.widgetWithText(CheckboxListTile, 'Maré noturna');
    final second = find.widgetWithText(CheckboxListTile, 'Horizonte');
    final cover = find.descendant(of: first, matching: find.byType(CoverArt));
    expect(
      tester.getCenter(cover).dx,
      lessThan(tester.getCenter(find.text('Maré noturna')).dx),
    );
    expect(tester.getTopLeft(second).dy, lessThan(tester.getTopLeft(first).dy));
    await tester.tap(first);
    await tester.pump();
    await tester.tap(second);
    await tester.pump();
    await tester.tap(find.text('Adicionar (2)'));
    await tester.pumpAndSettle();
    expect(playlist.trackIds, testTracks.map((track) => track.id).toList());
    state.dispose();
  });

  testWidgets(
    'adicionadas recentemente usa a data do arquivo e limita a 90 dias',
    (tester) async {
      final now = DateTime.now();
      Track track(String title, int? age) => Track.fromJson({
        ...testTracks.first.toJson(),
        'id': title,
        'title': title,
        'addedAt': now.millisecondsSinceEpoch,
        'createdAt': age == null
            ? null
            : now.subtract(Duration(days: age)).millisecondsSinceEpoch,
      });
      final state = await controller(
        rows: [
          track('Quase 90 dias', 89),
          track('Arquivo antigo', 91),
          track('Arquivo novo', 2),
          track('Sem data de arquivo', null),
        ],
      );
      expect(state.recentlyAdded.map((track) => track.title), [
        'Arquivo novo',
        'Quase 90 dias',
      ]);
      await tester.pumpWidget(MusicApp(controller: state));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();
      final recent = find.widgetWithText(ListTile, 'Adicionadas recentemente');
      expect(
        find.descendant(of: recent, matching: find.text('2 músicas')),
        findsOneWidget,
      );
      await tester.tap(recent);
      await tester.pumpAndSettle();
      expect(find.text('Arquivo antigo'), findsNothing);
      expect(find.text('Sem data de arquivo'), findsNothing);
      expect(find.text('Arquivo novo'), findsOneWidget);
      state.dispose();
    },
  );

  testWidgets('faixa arrastada usa fundo azul-marinho e muda de posição', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await controller();
    final playlist = await state.createPlaylist('Teste');
    await state.addToPlaylist(playlist, testTracks);
    await tester.pumpWidget(
      MusicScope(
        controller: state,
        child: MaterialApp(
          theme: buildTheme(),
          home: CollectionScreen(
            title: playlist.name,
            kind: 'playlist',
            value: playlist.id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final handles = find.byType(ReorderableDragStartListener);
    final start = tester.getCenter(handles.first);
    final end = Offset.lerp(start, tester.getCenter(handles.last), .8)!;
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 10));
    await tester.pump();
    await gesture.moveTo(end);
    await tester.pumpAndSettle();
    final darkProxy = find.byWidgetPredicate(
      (widget) =>
          widget is Material &&
          widget.color == AppColors.surface &&
          widget.elevation == 4,
    );
    expect(
      find.descendant(of: darkProxy, matching: find.byType(TrackTile)),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(playlist.trackIds, [testTracks.last.id, testTracks.first.id]);
    state.dispose();
  });

  testWidgets('permissão negada tem explicação e acesso às configurações', (
    tester,
  ) async {
    final state = await controller(allowed: false);
    await tester.pumpWidget(MusicApp(controller: state));
    await tester.pumpAndSettle();
    expect(find.text('Permitir acesso ao áudio'), findsOneWidget);
    expect(find.text('Abrir permissões do aplicativo'), findsOneWidget);
    expect(find.byKey(const Key('open-player')), findsNothing);
    state.dispose();
  });

  testWidgets('busca vazia, seleção real e player com três abas', (
    tester,
  ) async {
    final state = await controller();
    await tester.pumpWidget(MusicApp(controller: state));
    await tester.pumpAndSettle();
    expect(find.text('2 músicas'), findsOneWidget);
    await tester.tap(find.byTooltip('Pesquisar músicas'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma música encontrada'), findsOneWidget);
    await tester.tap(find.byTooltip('Pesquisar músicas'));
    await tester.pumpAndSettle();
    await state.select(testTracks.first, from: testTracks);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-player')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Letra'));
    await tester.pumpAndSettle();
    expect(find.text('Buscar Letra'), findsOneWidget);
    await tester.tap(find.text('Significado'));
    await tester.pumpAndSettle();
    expect(find.text('Buscar Significado'), findsOneWidget);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('tela estreita e fonte ampliada preservam navegação', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final state = await controller();
    await state.select(testTracks.first, from: testTracks);
    await tester.pumpWidget(MusicApp(controller: state));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('open-player')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Significado'));
    await tester.tap(find.text('Significado'));
    await tester.pumpAndSettle();
    expect(find.text('Buscar Significado'), findsOneWidget);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('índice alfabético navega até faixa fora da área visível', (
    tester,
  ) async {
    final rows = [
      for (var i = 0; i < 520; i++)
        Track.fromJson({
          ...testTracks.first.toJson(),
          'id': 'content://media/external/audio/media/${100 + i}',
          'title': switch (i) {
            517 => 'Zênite',
            518 => '*Asterisk',
            519 => 'Кукушка',
            _ => 'Aurora ${i.toString().padLeft(2, '0')}',
          },
        }),
    ];
    final state = await controller(rows: rows);
    await tester.pumpWidget(MusicApp(controller: state));
    await tester.pumpAndSettle();
    expect(find.text('Zênite').hitTestable(), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Z'));
    await tester.pumpAndSettle();
    expect(find.text('Zênite').hitTestable(), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'К'), findsNothing);
    final other = find.widgetWithText(TextButton, '*');
    expect(
      tester.getCenter(other).dy,
      greaterThan(tester.getCenter(find.widgetWithText(TextButton, 'Z')).dy),
    );
    await tester.tap(other);
    await tester.pumpAndSettle();
    expect(find.text('*Asterisk').hitTestable(), findsOneWidget);
    state.dispose();
  });

  testWidgets('puxar lista vazia lê arquivos recém-adicionados', (
    tester,
  ) async {
    final media = FakeMedia()..rows = [];
    final state = MusicController(
      media: media,
      store: MemoryStore(),
      handler: FakeHandler(),
    );
    addTearDown(state.dispose);
    await state.initialize();
    await tester.pumpWidget(MusicApp(controller: state));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma música no aparelho'), findsOneWidget);
    media.rows = [testTracks.first];
    await tester.drag(
      find.byType(CustomScrollView).hitTestable(),
      const Offset(0, 380),
    );
    await tester.pumpAndSettle();
    expect(find.text(testTracks.first.title), findsOneWidget);
    expect(find.text('1 música'), findsOneWidget);
    state.dispose();
  });
}
