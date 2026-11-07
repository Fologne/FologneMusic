# FologneMusic 1.0.0

## Instalar e usar no celular

Abra o APK assinado no instalador do Android e permita acesso ao áudio na primeira abertura. O app consulta a biblioteca ao abrir e ao voltar para o primeiro plano. Para consultar de novo, vá ao topo da lista e puxe para baixo ou toque no botão de atualizar. Arquivos recém-copiados aparecem depois que o Android os cataloga.

No player, toque em **Buscar Letra** ou **Buscar Significado**. A busca direta é o padrão e usa a internet do próprio celular. Letras vêm do [LRCLIB](https://lrclib.net/docs). Para significado, o app oferece os textos do catálogo com fontes e, quando identifica um artigo compatível, um link da Wikipédia. O botão **Salvar offline** só aparece quando o resultado autoriza a cópia. A música local e os textos salvos ficam disponíveis em modo avião.

O APK de release usa uma chave própria. O Android preserva dados em atualizações com o mesmo identificador e a mesma assinatura. Se uma versão de debug ainda estiver instalada, o Android não aceita substituí-la com a chave de release. Preserve o que precisar antes de remover uma instalação de debug. [Regras de atualização do Android](https://developer.android.com/google/play/app-updates).

## Gerar outra versão assinada

Use a mesma chave de release em todas as futuras versões deste aplicativo. Nesta máquina, a chave PKCS#12 está em `%LOCALAPPDATA%\FologneMusic\signing`. A senha local está protegida pelo Windows e vinculada ao usuário atual. Guarde uma cópia do arquivo da chave e da senha em um cofre com recuperação independente deste computador.

Defina `FOLOGNE_KEYSTORE` com o caminho da chave e `FOLOGNE_KEYSTORE_PASSWORD` no ambiente de build. O alias é `folognemusic`. A partir de `mobile`, execute:

```powershell
flutter pub get
flutter build apk --release
```

O APK fica em `build/app/outputs/flutter-apk/app-release.apk`. Use o `apksigner verify --print-certs` do SDK Android para conferir o certificado e calcule o SHA-256 do APK antes de distribuí-lo.

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
