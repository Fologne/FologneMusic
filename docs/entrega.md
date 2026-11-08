# Entrega do FologneMusic

## Versão 2.0.0

O APK `FologneMusic-2.0.0.apk` usa o identificador `com.musicapp.music_app`, a chave da versão 1.0.0 e o código de versão 16. A fila de reprodução mostra a ordem do modo aleatório e restaura essa ordem ao reabrir o app. A aba **Downloads** usa a mesma fila para links compartilhados e colados. Seu histórico fica separado do SQLite da biblioteca. Limpar o histórico mantém os MP3 salvos em `Music/FologneMusic`.

O download de áudio funciona a partir do Android 10 em ARM64 ou x86-64. No emulador, o teste do APK assinado da rc.3 baixou o áudio de um vídeo autorizado, converteu para MP3 e abriu a faixa no player. [Configuração da compilação com downloads](desenvolvimento.md#protótipo-de-download-de-áudio).

### Arquivo e verificação

| Item | Valor |
| --- | --- |
| APK | `FologneMusic-2.0.0.apk` |
| Tamanho | 128.478.945 bytes |
| SHA-256 do APK | `5b6af1c691826f912094249a65f21eb1a203b0771169d3801a808614e13a6628` |
| SHA-256 do certificado | `f2921d73b8caa843456b9fb36efae838e27723135d7e556a1f57f66eaf7a9a21` |
| Código do app usado no build | Base `f90d0acd4b158e19e04464810ac8e0fc10ca4a4c` com a correção da fila incluída no pacote de fontes |
| SDK | Android 7.0 para o player e Android 10 para download e conversão |
| ABIs | `arm64-v8a` e `x86_64` |

### Licenças e código-fonte

O código original do FologneMusic é distribuído sob `GPL-3.0-only`. [Texto da licença](../LICENSE)

Os binários nativos do APK correspondem byte a byte aos incluídos nos AARs 0.18.1 para as duas arquiteturas. O zipapp principal de yt-dlp tem o SHA-256 fixado no Gradle. A biblioteca também inclui uma cópia de yt-dlp como recurso interno.

| Componente | Licença e fonte identificadas |
| --- | --- |
| youtubedl-android 0.18.1 | GPL-3.0 declarada no Maven Central. A tag aponta para `d725d5c9a18c3a99a13ee0308bf78275dc310760`. Há arquivos `sources.jar` para [library](https://repo.maven.apache.org/maven2/io/github/junkfood02/youtubedl-android/library/0.18.1/library-0.18.1-sources.jar), [common](https://repo.maven.apache.org/maven2/io/github/junkfood02/youtubedl-android/common/0.18.1/common-0.18.1-sources.jar) e [ffmpeg](https://repo.maven.apache.org/maven2/io/github/junkfood02/youtubedl-android/ffmpeg/0.18.1/ffmpeg-0.18.1-sources.jar). [Tag da biblioteca](https://github.com/yausername/youtubedl-android/tree/0.18.1) |
| FFmpeg e FFprobe 7.1.1 | A configuração dos binários inclui `--enable-gpl` e `--enable-version3`. O pacote também contém as bibliotecas que eles carregam. [Atualização dos binários](https://github.com/yausername/youtubedl-android/commit/f2280ae7d8bc8d59590c8727a89f047983867c10) · [Fonte base 7.1.1](https://ffmpeg.org/releases/ffmpeg-7.1.1.tar.xz) · [Instruções da biblioteca](https://github.com/yausername/youtubedl-android/blob/0.18.1/BUILD_FFMPEG.md) |
| CPython 3.12.11 e QuickJS 2025-04-26 | A fonte base do CPython inclui a licença da PSF. QuickJS usa MIT. O pacote Python também inclui mutagen 1.47.0 (GPL-2.0-or-later), pycryptodomex 3.23.0 e bibliotecas nativas como GNU Readline. [CPython](https://www.python.org/downloads/release/python-31211/) · [QuickJS](https://bellard.org/quickjs/) · [Instruções da biblioteca](https://github.com/yausername/youtubedl-android/blob/0.18.1/BUILD_PYTHON.md) |
| yt-dlp e yt-dlp-ejs | O app usa o zipapp 2026.10.26 com EJS 0.8.0. O recurso interno da biblioteca contém yt-dlp 2025.11.12 com EJS 0.3.1. yt-dlp usa Unlicense e os zipapps incluem código ISC e MIT. [Licenças da versão usada pelo app](https://github.com/yt-dlp/yt-dlp/blob/2026.10.26/THIRD_PARTY_LICENSES.txt) · [Licenças da versão interna](https://github.com/yt-dlp/yt-dlp/blob/2025.11.12/THIRD_PARTY_LICENSES.txt) |

As receitas do Termux no commit `8ddd9a7fc8e06330545487d81bb7591cb40f1aa6` são uma referência para FFmpeg 7.1.1 e suas dependências. Os guias da biblioteca descrevem o processo geral, mas não fixam todas as revisões, os patches e as instruções usadas nos binários Android 0.18.1. A correspondência completa das fontes de FFmpeg, Python, QuickJS e das bibliotecas empacotadas ainda precisa ser confirmada para ARM64 e x86-64. [Receitas do Termux](https://github.com/termux/termux-packages/tree/8ddd9a7fc8e06330545487d81bb7591cb40f1aa6/packages) · [Levantamento do mesmo pacote pelo Sieve](https://github.com/Massivemiike/sieve-android/blob/e8467a8691dcdaf8aa5b26056ca5b2f3e7a10e76/licenses/FFMPEG_SOURCE.txt#L93)

O pacote `FologneMusic-2.0.0-fontes-e-avisos.zip` reúne as fontes obtidas, os avisos presentes nos arquivos de origem e no próprio APK, os hashes dos binários e as receitas de referência. O manifesto `FONTES.json` identifica as fontes obtidas e os endereços pendentes. Antes de publicar o APK com Downloads, confirme a correspondência dos binários pendentes e complete os avisos aplicáveis. Na distribuição pela internet, o acesso à fonte deve ser equivalente ao acesso ao APK e as notas da release devem indicar onde obtê-la. [FAQ da GPL](https://www.gnu.org/licenses/gpl-faq.en.html#SourceAndBinaryOnDifferentSites) · [Licenciamento do FFmpeg](https://ffmpeg.org/legal.html)

### Rascunho no GitHub

1. Inclua a documentação no commit e envie-o para a branch `master`.
2. Abra [Releases do FologneMusic](https://github.com/Fologne/FologneMusic/releases) e selecione **Draft a new release**.
3. Use a tag `v2.0.0`, o título `FologneMusic 2.0.0` e a branch `master` com a documentação atualizada. Cole as [notas da versão](release-2.0.0.md).
4. Anexe `FologneMusic-2.0.0.apk` e `FologneMusic-2.0.0-fontes-e-avisos.zip` em **Assets**. Os dois arquivos estão em `D:/FologneMusicBuild/release/v2.0.0/` no computador de compilação.
5. Salve com **Save draft**. Publique após confirmar as fontes e os avisos pendentes. [Instruções do GitHub](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository#creating-a-release)

## Instalar e usar no celular

Abra o APK assinado no instalador do Android e permita acesso ao áudio na primeira abertura. O app consulta a biblioteca ao abrir e ao voltar para o primeiro plano. Para consultar de novo, vá ao topo da lista e puxe para baixo ou toque no botão de atualizar. Arquivos recém-copiados aparecem depois que o Android os cataloga.

No player, toque em **Buscar Letra** ou **Buscar Significado**. A busca direta é o padrão e usa a internet do próprio celular. Letras vêm do [LRCLIB](https://lrclib.net/docs). Para significado, o app oferece os textos do catálogo com fontes e, quando identifica um artigo compatível, um link da Wikipédia. O botão **Salvar offline** só aparece quando o resultado autoriza a cópia. A música local e os textos salvos ficam disponíveis em modo avião.

O APK de release usa uma chave própria. O Android preserva dados em atualizações com o mesmo identificador e a mesma assinatura. Se uma versão de debug ainda estiver instalada, o Android não aceita substituí-la com a chave de release. Preserve o que precisar antes de remover uma instalação de debug. [Regras de atualização do Android](https://developer.android.com/google/play/app-updates).

## Gerar outra versão assinada

Use a mesma chave de release em todas as futuras versões deste aplicativo. Nesta máquina, a chave PKCS#12 está em `%LOCALAPPDATA%\FologneMusic\signing`. A senha local está protegida pelo Windows e vinculada ao usuário atual. Guarde uma cópia do arquivo da chave e da senha em um cofre com recuperação independente deste computador.

Defina `FOLOGNE_KEYSTORE` com o caminho da chave e `FOLOGNE_KEYSTORE_PASSWORD` no ambiente de build. O alias é `folognemusic`. A partir de `mobile`, execute:

```powershell
$env:FOLOGNE_EXPERIMENTAL_DOWNLOADS = 'true'
$env:FOLOGNE_YTDLP_ZIPAPP = 'C:/caminho/yt-dlp'
flutter build apk --release --target-platform android-arm64,android-x64
```

A versão 2.0.0 foi compilada com Flutter 3.47.8. Use o arquivo `yt-dlp` da [release 2026.10.26](https://github.com/yt-dlp/yt-dlp/releases/tag/2026.10.26). O APK fica em `build/app/outputs/flutter-apk/app-release.apk`. Use `apksigner verify --print-certs` do SDK Android para conferir o certificado e `Get-FileHash -Algorithm SHA256` para calcular o SHA-256.

O modo direto dispensa a configuração de URL. Se você já opera um Django em HTTPS, pode informar o endereço em **Menu → Configurações → Busca de textos → Usar servidor Django**. Para usar um servidor desde a primeira abertura, informe `--dart-define=API_BASE_URL=https://seu-dominio` no build.

## Django opcional com Docker

Para desenvolvimento local, na raiz:

```powershell
docker compose up -d --build --wait
docker compose exec django python manage.py migrate --noinput
docker compose logs -f django
docker compose down
```

O serviço de desenvolvimento escuta em `127.0.0.1:8000` por padrão. Ajuste a porta com `FOLOGNE_PORT`. Para testar pelo USB com um APK de debug, use `adb reverse tcp:8000 tcp:8000` e informe `http://127.0.0.1:8000` nas configurações do aplicativo.

O arquivo `compose.production.yaml` inicia Gunicorn sem privilégios e publica a porta apenas no loopback. Para uma implantação opcional, forneça `FOLOGNE_DJANGO_SECRET_FILE` com o caminho de um arquivo de chave fora do projeto, ajuste `DJANGO_ALLOWED_HOSTS` e coloque um proxy HTTPS à frente do serviço. Ative `DJANGO_REQUIRE_HTTPS=true` e `DJANGO_TRUST_PROXY=true` quando o proxy substituir o cabeçalho `X-Forwarded-Proto`. Use `docker compose -f compose.production.yaml up -d --build --wait` e rode as migrações com o mesmo arquivo Compose. Configure o acesso público e os limites no proxy. HSTS para subdomínios e preload dependem do domínio que você controla.

O volume `django-data` guarda o SQLite e permanece após `down`. Para backup com o serviço parado, copie `/data/db.sqlite3` do container para um local privado. Para restaurar, substitua esse arquivo no volume com o serviço parado, preserve a propriedade do usuário 10001 e rode as migrações antes de subir. Playlists e downloads do Android são armazenados no próprio celular.
