import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/library/music_controller.dart';
import 'package:music_app/main.dart';

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
