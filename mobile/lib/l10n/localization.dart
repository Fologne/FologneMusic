import 'package:flutter/widgets.dart';

import '../content/content_api.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

enum AppLanguage {
  system,
  pt,
  en;

  static AppLanguage fromPreference(String? value) => switch (value) {
    'pt' => pt,
    'en' => en,
    _ => system,
  };

  Locale? get locale => this == system ? null : Locale(name);
}

Locale resolveAppLocale(Locale? primary) =>
    primary?.languageCode == 'pt' ? const Locale('pt') : const Locale('en');

extension LocalizedContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String textKindLabel(TextKind kind) => switch (kind) {
    TextKind.lyrics => l10n.lyrics,
    TextKind.meaning => l10n.meaning,
  };

  String localizedMessage(String message) => localizeMessage(l10n, message);
}

// Match existing download history and platform errors in addition to new events.
String localizeMessage(
  AppLocalizations strings,
  String message,
) => switch (message) {
  'Não foi possível abrir os dados locais. Tente reiniciar o aplicativo.' =>
    strings.localDataReadFailed,
  'A fila foi atualizada: há arquivos que não estão mais disponíveis.' =>
    strings.queueFilesMissing,
  'Não foi possível atualizar a biblioteca. Verifique as permissões e tente novamente.' =>
    strings.libraryRefreshFailed,
  'Esta música está indisponível. Atualize a biblioteca ou conceda acesso ao áudio.' =>
    strings.trackUnavailable,
  'Não foi possível salvar os dados locais. Verifique o espaço disponível.' =>
    strings.localDataSaveFailed,
  'Não foi possível tocar este arquivo. Ele pode ter sido removido ou estar corrompido.' =>
    strings.playbackFileFailed,
  'Não foi possível reproduzir. Verifique o arquivo e a permissão de áudio.' =>
    strings.playbackFailed,
  'A reprodução foi interrompida. Tente selecionar outra música.' =>
    strings.playbackInterrupted,
  'Limite de buscas atingido. Tente em instantes.' => strings.textSearchLimit,
  'A busca expirou. Pesquise novamente.' => strings.textSearchExpired,
  'Confira o título, o artista e a duração da busca.' =>
    strings.textSearchInvalid,
  'O servidor não conseguiu atender à busca.' => strings.serverSearchFailed,
  'A fonte atingiu o limite de consultas. Tente em instantes.' =>
    strings.sourceQueryLimit,
  'A fonte está indisponível. Tente novamente mais tarde.' =>
    strings.sourceTryLater,
  'Sem conexão com o servidor de textos.' => strings.textServerOffline,
  'A busca demorou demais. Tente novamente.' => strings.textSearchTimeout,
  'A fonte pediu uma pausa entre buscas. Tente novamente em instantes.' =>
    strings.sourceRequestedPause,
  'A fonte está ocupada. Tente novamente em instantes.' => strings.sourceBusy,
  'Sem conexão com a fonte de textos.' => strings.textSourceOffline,
  'Esta fonte não permite salvar o texto offline.' =>
    strings.offlineSavingUnavailable,
  'Limite de 20 MiB atingido. Remova um download nas configurações.' =>
    strings.offlineStorageLimit,
  'Download interrompido ao fechar o aplicativo.' =>
    strings.downloadInterrupted,
  'Não foi possível identificar o MP3 salvo.' => strings.savedMp3Unknown,
  'Link inválido.' => strings.downloadInvalid,
  'Requer Android 10 ou superior.' => strings.downloadAndroidVersion,
  'Já há um download em andamento.' => strings.downloadBusy,
  'Abra o FologneMusic e tente novamente.' => strings.downloadBackground,
  'Espaço insuficiente para converter a música.' =>
    strings.conversionStorageFull,
  'Download cancelado.' => strings.downloadCanceled,
  'O link não forneceu um áudio disponível.' => strings.downloadNoAudio,
  'Não foi possível iniciar o conversor de áudio.' =>
    strings.downloadConverterFailed,
  'Espaço insuficiente para salvar a música.' => strings.downloadStorageFull,
  'Não foi possível baixar ou converter o áudio. Verifique a conexão e o link.' =>
    strings.downloadConversionFailed,
  'Esta música já está na pasta do FologneMusic.' =>
    strings.downloadDuplicateFile,
  'Sem título' => strings.untitled,
  'Não foi possível abrir o texto salvo.' => strings.savedTextOpenFailed,
  'A fonte atingiu o limite. Tente novamente em instantes.' =>
    strings.sourceRateLimited,
  'A fonte está indisponível no momento.' => strings.sourceUnavailable,
  'Letra não encontrada. Confira o título e o artista da busca.' =>
    strings.lyricsSearchFailed,
  'Não foi possível ler a resposta do servidor.' =>
    strings.serverResponseReadFailed,
  'Não foi possível salvar o texto neste aparelho.' => strings.textSaveFailed,
  'Não foi possível abrir o link.' => strings.linkOpenFailed,
  'Artista desconhecido' => strings.unknownArtist,
  'Álbum desconhecido' => strings.unknownAlbum,
  _ => message,
};
