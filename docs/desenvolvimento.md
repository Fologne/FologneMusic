# Desenvolvimento

## Ambiente

Base utilizada: Flutter 3.47.8, Dart 3.13.7, Python 3.14.7 e Django 5.2.19. O Flutter detectou o SDK Android instalado e o Java do Android Studio. O aviso de Chrome ausente não afeta o alvo Android.

Os comandos abaixo são para PowerShell, a partir da raiz do projeto, salvo indicação contrária. Não é necessário usar GitHub para executar ou testar.

## Backend

```powershell
python -m venv backend/.venv
backend/.venv/Scripts/python.exe -m pip install -r backend/requirements-dev.txt
$env:DJANGO_DEBUG = 'true'
backend/.venv/Scripts/python.exe backend/manage.py migrate
backend/.venv/Scripts/python.exe backend/manage.py runserver 127.0.0.1:8000
```

O arquivo `backend/.env.example` apenas documenta variáveis. Não é carregado automaticamente. Para definir outras variáveis, use `$env:NOME = 'valor'` no terminal antes de iniciar o Django. Em produção, `DJANGO_SECRET_KEY` é obrigatória e `DJANGO_DEBUG` deve permanecer desativado.

## Flutter no emulador

Em outro terminal:

```powershell
cd mobile
flutter pub get
flutter emulators
flutter emulators --launch Medium_Phone_API_37.0
flutter devices
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Use o ID real exibido por `flutter devices`. O nome do emulador acima é o disponível neste computador. `10.0.2.2` acessa o computador a partir do emulador Android.

Em Configurações, toque em Verificar conexão. A mensagem esperada é “Servidor conectado”. A biblioteca não exige que o backend esteja ativo.

## POCO X5 Pro por USB

Ative a depuração USB e autorize o computador no celular. Com o Django ainda ativo:

```powershell
adb devices
adb -s ID_DO_CELULAR reverse tcp:8000 tcp:8000
cd mobile
flutter run -d ID_DO_CELULAR --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Substitua `ID_DO_CELULAR` pelo identificador retornado pelo ADB. Se `adb` não estiver no PATH, use o executável em `Android/Sdk/platform-tools` da instalação local. O encaminhamento por USB dispensa abrir uma porta na rede.

Para Wi-Fi, use o IPv4 do computador em `API_BASE_URL`, inclua esse IP em `DJANGO_ALLOWED_HOSTS` e inicie Django em `0.0.0.0:8000` numa rede confiável. Libere a porta no firewall apenas se necessário. Não use `localhost` no celular para acessar o computador.

HTTP sem TLS é permitido somente no manifesto de debug. O APK de release é assinado com chave própria e usa HTTPS nas buscas.

Com a configuração acima, as buscas passam pelo Django local via USB. No app, altere essa opção em **Menu → Configurações → Busca de textos**. Por padrão, o APK de release consulta as fontes diretamente pela internet do celular.

## Verificações

### Protótipo de download de áudio

O fluxo de MP3 é experimental e exige Android 10 ou superior em ARM64 ou x86-64. A compilação padrão mantém o recebimento do link. Para compilar a variante de teste, baixe o arquivo `yt-dlp` da versão fixada e habilite a integração antes do build. O Gradle verifica o SHA-256 do arquivo. [yt-dlp 2026.10.26](https://github.com/yt-dlp/yt-dlp/releases/tag/2026.10.26).

```powershell
$env:FOLOGNE_EXPERIMENTAL_DOWNLOADS = 'true'
$env:FOLOGNE_YTDLP_ZIPAPP = 'C:/caminho/yt-dlp'
cd mobile
flutter build apk --debug
```

Essa variante de debug usa o identificador `com.musicapp.music_app.qa`. Para o teste integrado, sirva um WAV de teste como `fologne-test.wav` em uma porta local e encaminhe essa porta para o emulador com `adb reverse`. Execute o comando abaixo a partir de `mobile`.

```powershell
flutter test integration_test/audio_download_test.dart -d emulator-5554 --dart-define=FOLOGNE_AUDIO_FIXTURE_URL=http://127.0.0.1:18791/fologne-test.wav
```

O servidor local serve apenas o arquivo de teste. O APK processa links compartilhados no Android, com yt-dlp, Python, QuickJS e FFmpeg empacotados. Quando o extrator precisar de atualização, revise a versão, o SHA-256 e o marcador em `AudioDownloads.kt`, recompilando o APK. A distribuição pública do protótipo depende da revisão das licenças dos componentes empacotados. [youtubedl-android](https://github.com/yausername/youtubedl-android).

### Verificações de rotina

Backend, a partir da raiz:

```powershell
$env:DJANGO_DEBUG = 'true'
backend/.venv/Scripts/python.exe backend/manage.py check
backend/.venv/Scripts/python.exe backend/manage.py test core --top-level-directory backend
backend/.venv/Scripts/python.exe -m ruff check backend
backend/.venv/Scripts/python.exe -m ruff format --check backend
```

Flutter, a partir de `mobile`:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test/app_test.dart -d emulator-5554
flutter build apk --debug
```

O teste de integração atual exige o emulador com permissão de áudio e arquivos WAV preparados conforme `docs/audio-local.md`. Não depende de Django. Os testes locais não dependem de internet ou provedores externos; o teste de saúde HTTP usa um servidor temporário.

Neste computador, o processo do emulador encerrou durante testes com a configuração gráfica padrão. O teste integrado passou após iniciar o emulador com `-gpu swangle -feature -Vulkan -cores 2 -no-snapshot` e executar `flutter test integration_test/app_test.dart -d emulator-5554 --no-enable-impeller`. Para abrir a prévia nesse ambiente, use também `--no-enable-impeller` em `flutter run`. Essa configuração é de teste; não altera o renderer padrão do projeto ou comprova comportamento no POCO. A opção é descrita na [documentação do Flutter sobre Impeller](https://docs.flutter.dev/perf/impeller).

## Arquivos locais

O `.gitignore` ignora tudo por padrão e libera os arquivos do projeto explicitamente. Ambientes virtuais, caches, banco SQLite, logs, APKs, chaves e configurações locais permanecem ignorados. Novos diretórios de código precisam ser liberados quando forem criados.
