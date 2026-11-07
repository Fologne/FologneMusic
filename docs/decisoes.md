# Decisões iniciais

## Produto

MusicAPP é o nome provisório. O identificador de desenvolvimento é `com.musicapp.music_app`. O ícone Android ainda é o padrão do Flutter; a identidade final fica para a entrega do APK de release.

O primeiro alvo físico é o POCO X5 Pro com Android 14 e HyperOS 2.0.17.0, informado pelo usuário. O mínimo configurado é Android 7.0, API 24. Isso é uma configuração inicial, não uma declaração de testes em todas as versões. O emulador disponível usa API 37.

O MVP reproduzirá arquivos locais, sem conta e sem anúncios. Streaming e download de áudio estão fora desse escopo. Letras e significados terão download manual, JSON UTF-8 versionado e leitura offline. O limite inicial proposto para textos é 20 MiB, com limpeza manual; ainda não implementado.

O desenvolvimento usa Django local, sem hospedagem paga. A escolha de hospedagem de produção será feita antes da etapa de implantação.

## Interface

O tema usa preto `#05080F`, azul-marinho `#0A1730`, superfícies `#101D31`, texto `#F2F5FC`, texto secundário `#A4B1C6` e destaque azul `#8FBEFF`.

As referências orientam a biblioteca com abas, miniplayer, detalhes de playlist e fila inferior. O player acrescenta a aba Significado ao lado de Música e Letra. Capas desta prévia são desenhos gerados pelo próprio Flutter; não precisam de internet.

A versão 0.2.0 substitui os dados de demonstração por arquivos reais catalogados no aparelho, reprodução de áudio e persistência local. Letras e significados exibem uma indicação de recurso ainda não disponível, sem conteúdo fictício associado às músicas.

## Organização técnica

- `mobile/lib/core`: tema e cliente HTTP de saúde.
- `mobile/lib/library`: modelos, consulta de mídia, SQLite e estado da biblioteca.
- `mobile/lib/playback`: mecanismo de reprodução e sessão de mídia Android.
- `mobile/lib/features`: biblioteca, detalhes, player, textos e configurações.
- `mobile/lib/widgets`: componentes visuais reutilizáveis.
- `backend/config`: configuração, rotas e entradas WSGI/ASGI.
- `backend/core`: endpoint de saúde e seus testes.

Flutter usa Material 3, localização pt-BR e `ChangeNotifier` para o estado da interface. A reprodução usa just_audio, audio_service e audio_session; a persistência usa sqflite. A leitura do catálogo Android usa um canal nativo próprio. As versões resolvidas estão em `pubspec.lock`.

Django usa REST Framework e SQLite no desenvolvimento. Não há autenticação ou dados pessoais no endpoint de saúde. A API de conteúdos será implementada depois, com proteção contra abuso. A configuração falha sem chave secreta quando `DJANGO_DEBUG` não está ativo.

## Contrato implementado

`GET /api/v1/health/` retorna HTTP 200:

```json
{"status":"ok","service":"musicapp","api_version":"v1"}
```

A resposta não usa cache e não depende de provedores externos ou do banco. Ela verifica a disponibilidade do processo HTTP; não é um teste de prontidão das integrações futuras. Outros métodos retornam 405. Rotas de letras e significados ainda não existem e retornam 404.

## Referências técnicas

- [Configuração Android no Flutter](https://docs.flutter.dev/platform-integration/android/setup).
- [Compatibilidade do Django 5.2 com Python](https://docs.djangoproject.com/en/5.2/releases/5.2/).
