# FologneMusic

[Read in English](README.en.md)

Player de músicas locais para Android, feito em Flutter. A busca de letras e significados usa a internet do celular. O servidor Django com Docker é opcional.

## Instalação

Requer Android 7.0 ou superior.

1. Abra a página de [Releases](https://github.com/Fologne/FologneMusic/releases). Quando a 2.0.0 estiver publicada, baixe `FologneMusic-2.0.0.apk` em **Assets**.
2. Abra o APK em **Downloads** pelo gerenciador de arquivos do Android. Se o sistema solicitar, autorize a instalação a partir desse gerenciador e confirme.
3. Abra o FologneMusic e conceda acesso ao áudio. O app carrega as músicas armazenadas no celular que o Android já catalogou.

Para atualizar, abra o APK de uma versão mais recente sobre a instalação existente. O Android preserva os dados quando os APKs usam o mesmo identificador e a mesma assinatura. [Regras de atualização do Android](https://developer.android.com/google/play/app-updates).

## Funcionalidades

- Biblioteca por faixas, pastas e álbuns, com busca por título, artista ou álbum, ordenação e índice alfabético.
- Atualização da biblioteca ao abrir o app, voltar a ele ou puxar a lista para baixo. Também há um botão para atualizar.
- Reprodução local em segundo plano, miniplayer, fila editável, avanço na faixa, modo aleatório e repetição. Os botões **Anterior** e **Próxima** seguem a fila com um toque.
- Controles na notificação e na tela bloqueada, com capa nas cores originais e botão X para parar a reprodução. O sistema define a cor do cartão.
- Restauração da fila e da posição ao reabrir, com início da reprodução sob comando do usuário.
- Criação e edição de playlists, com seleção múltipla de faixas na ordem dos toques, capas no seletor, reordenação por arraste com destaque em azul-marinho e capa escolhida entre as músicas da lista.
- Favoritos, histórico e músicas mais ouvidas. **Adicionadas recentemente** mostra os arquivos dos últimos 90 dias, do mais novo ao mais antigo. A lista usa a data de criação quando o Android a disponibiliza e a data de modificação como alternativa.
- Exclusão de músicas pelo menu da faixa, com confirmação.
- Player com as abas **Música**, **Letra** e **Significado**, temporizador para pausar e opções de aparência.
- Tema escuro azul-marinho e preto, com opção de fundo mais escuro, capa no fundo e ajuste do tamanho do texto.

## Downloads de áudio

Disponível a partir do Android 10. No YouTube, toque em **Compartilhar** e escolha **FologneMusic**, ou cole o link na aba **Downloads**. Confirme em **Baixar MP3** para vídeos cujo download e conversão você tem autorização.

A aba mostra a fila, o progresso e o histórico local, com opções para cancelar, tentar novamente e reproduzir os arquivos concluídos. A conversão acontece no celular e salva os MP3 em `Music/FologneMusic`. [Como compilar com suporte a downloads](docs/desenvolvimento.md#protótipo-de-download-de-áudio).

## Letras e significados

No player, use **Buscar Letra** ou **Buscar Significado**. Se os metadados do arquivo estiverem incorretos, use **Corrigir busca** para ajustar o título ou o artista.

As letras vêm do LRCLIB e são exibidas online. A aba **Significado** mostra textos do catálogo do app e, quando há um artigo correspondente, um link da Wikipédia. A disponibilidade varia conforme a faixa.

Quando houver autorização para download, toque em **Salvar offline**. Gerencie os downloads em **Menu → Textos salvos**. As músicas locais e os textos já salvos funcionam sem conexão.

## Desenvolvimento

- [Como executar e testar](docs/desenvolvimento.md)
- [Biblioteca e reprodução local](docs/audio-local.md)
- [Decisões do projeto](docs/decisoes.md)
- [Fontes de letras e significados](docs/fontes.md)
- [API de letras e significados](docs/api-conteudo.md)
- [Instalação, assinatura e Docker](docs/entrega.md)
