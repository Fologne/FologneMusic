# Biblioteca e reprodução local

## Uso

Na primeira abertura, toque em Permitir acesso ao áudio. Se o Android impedir uma nova solicitação, use Abrir permissões do aplicativo. O app consulta os arquivos catalogados pelo Android; copie suas músicas para o celular e atualize a biblioteca.

Faixas podem ser pesquisadas por título, artista ou álbum e ordenadas por título, artista, álbum ou data de adição. Pressione uma faixa por alguns instantes para selecionar várias e adicioná-las a uma playlist. Pastas e álbuns são agrupados pelos metadados disponíveis.

O menu de cada faixa permite favoritar, adicionar à playlist e consultar informações. Uma playlist permite adicionar/remover faixas, renomear, excluir, escolher a capa de uma de suas músicas e reordenar por arraste. A ordenação manual fica disponível sem busca ou ordenação temporária. Duplicatas não são inseridas. Excluir uma playlist não apaga músicas.

O player oferece pausa, avanço, retrocesso, posição, aleatório, repetição e fila reordenável. O botão anterior volta ao início após três segundos; antes disso, vai à faixa anterior. Ao chegar ao fim sem repetição, a reprodução para. O controle Encerrar reprodução nas configurações libera o serviço de áudio.

No player, **Temporizador** programa uma pausa entre 5 e 60 minutos. Em **Configurações**, é possível ajustar o tamanho dos textos, usar um tema mais escuro e alternar a capa no fundo do player e das playlists. Na ordem por título, bibliotecas com pelo menos 20 faixas mostram o índice lateral.

## Letras e significados

Nas abas do player, inicie a busca manualmente. A API reconhece nomes de vídeos como `505 - Arctic Monkeys (Tradução/Letra)`, canais `- Topic` e `VEVO` e algumas variantes de título, como `*Asterisk`. Use **Corrigir busca** se ainda não houver correspondência. A letra mantém o idioma da fonte. Se uma gravação escolhida tiver duração diferente, o texto aparece sem sincronização.

Use **Salvar offline** nos resultados autorizados. Em **Menu → Textos salvos**, veja o tamanho dos downloads e remova os textos de uma faixa. O app guarda um JSON UTF-8 por faixa em armazenamento privado, com registros independentes de letra e significado, e um limite total de 20 MiB.

As letras do LRCLIB estão disponíveis para consulta online. Os textos próprios de significado podem ser baixados. A Wikipédia retorna links de contexto. As regras e fontes estão em [Fontes de letras e significados](fontes.md).

## Armazenamento

A biblioteca é obtida por MediaStore em uma thread nativa. Reprodução usa URIs `content://`, sem enviar áudio ao Django. Capas embutidas são extraídas sob demanda, reduzidas a até 512 pixels e mantidas em cache limitado; arquivos sem capa usam a ilustração padrão.

SQLite mantém uma tabela de faixas e um documento de estado versionado. O estado contém playlists, favoritos, histórico, ordenação, fila, posição e modos de reprodução. As gravações são serializadas e atômicas. A biblioteca é gravada ao atualizar; a posição é salva a cada cinco segundos, nas ações do player e nas mudanças de ciclo de vida. Um encerramento abrupto pode perder os últimos segundos de posição.

Ao reabrir, fila e posição são restauradas pausadas. Arquivos removidos ficam sinalizados como indisponíveis nas playlists; as referências não são apagadas silenciosamente. A fila filtra arquivos ausentes após atualização. Revogar a permissão interrompe o acesso e mantém a organização salva.

O histórico registra uma reprodução após 30 segundos efetivamente acompanhados ou metade da duração de faixas curtas. Avançar a barra não conta como tempo ouvido. São mantidos até 1.000 registros; Mais ouvidas considera essa janela. É possível limpar o histórico sem apagar favoritos ou playlists.

## Android

`just_audio` executa a reprodução; `audio_service` integra a sessão de mídia, notificação e controles; `audio_session` configura o foco de áudio para música. O serviço permanece em primeiro plano durante pausas para permitir retomada pelos controles do sistema. Encerrar reprodução o interrompe.

A notificação usa as cores originais da capa embutida. No POCO, o HyperOS calcula a cor do cartão nativo a partir dessa imagem. Faixas sem capa usam uma imagem padrão azul-marinho. [Documentação da Xiaomi sobre notificações de mídia](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=2161).

A configuração usa `READ_MEDIA_AUDIO` no Android 13 ou posterior e `READ_EXTERNAL_STORAGE` nas versões anteriores, além das permissões de serviço de reprodução. Não solicita acesso a fotos, vídeos ou gerenciamento de todos os arquivos.

A integração de foco de áudio e retirada de fones usa o tratamento do mecanismo de reprodução. No POCO X5 Pro com Android 14 e HyperOS 2.0.17.0, o APK de debug manteve a reprodução com a tela apagada e respondeu a comandos de mídia de pausa e retomada enquanto bloqueado. Chamadas reais, fones, Bluetooth e reprodução prolongada com as restrições de bateria ainda precisam de validação.

No emulador, uma chamada GSM simulada pausou a música ao ficar ativa. O player permaneceu pausado ao encerrar a chamada.

Para conferir no POCO com o APK de debug, toque uma faixa local, vá para a tela inicial e bloqueie o aparelho. Use o cartão de mídia para pausar, retomar e trocar de faixa. Em seguida, teste uma chamada recebida, a desconexão dos fones e os botões de um acessório Bluetooth. Observe se a reprodução continua após alguns minutos com a tela apagada e registre o modo de bateria do app no HyperOS.

## Testes de integração

Os arquivos de teste são tons sintéticos criados localmente, sem conteúdo musical de terceiros:

```powershell
python mobile/tool/create_test_audio.py artifacts/test-audio
adb shell mkdir -p /sdcard/Music/MusicAPP_Test
adb push artifacts/test-audio/. /sdcard/Music/MusicAPP_Test/
```

Solicite ao Android a indexação de cada arquivo antes do teste:

```powershell
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Music/MusicAPP_Test/MusicAPP_Test_01.wav
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Music/MusicAPP_Test/MusicAPP_Test_02.wav
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Music/MusicAPP_Test/MusicAPP_Test_03.wav
```

Instale o APK debug e conceda acesso ao áudio no emulador Android 13 ou posterior:

```powershell
cd mobile
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell pm grant com.musicapp.music_app android.permission.READ_MEDIA_AUDIO
flutter test integration_test/app_test.dart -d emulator-5554 --no-enable-impeller
```

Use o ID do dispositivo disponível. O teste usa os arquivos locais e SQLite real; não depende de Django ou de internet. Não execute em um aparelho com dados de produção: ele cria uma playlist de teste, modifica a fila e registra histórico dos tons sintéticos.

## Referências

- [MediaStore e acesso a áudio no Android](https://developer.android.com/training/data-storage/shared/media).
- [just_audio](https://pub.dev/packages/just_audio).
- [audio_service](https://pub.dev/packages/audio_service).
- [audio_session](https://pub.dev/packages/audio_session).
