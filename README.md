# FologneMusic

Player de músicas locais para Android, feito em Flutter. A busca de letras e significados usa a internet do celular. O servidor Django com Docker é opcional.

## Instalação

Requer Android 7.0 ou superior.

1. Abra a página de [Releases](https://github.com/Fologne/RhapsodyMusic/releases) e baixe o arquivo `FologneMusic-1.0.0.apk` em **Assets** da versão 1.0.0.
2. Abra o APK em **Downloads** pelo gerenciador de arquivos do Android. Se o sistema solicitar, autorize a instalação a partir desse gerenciador e confirme.
3. Abra o FologneMusic e conceda acesso ao áudio. O app carrega as músicas armazenadas no celular que o Android já catalogou.

Para atualizar, abra o APK de uma versão mais recente sobre a instalação existente. O Android preserva os dados quando os APKs usam o mesmo identificador e a mesma assinatura. [Regras de atualização do Android](https://developer.android.com/google/play/app-updates).

## Funcionalidades

- Biblioteca por faixas, pastas e álbuns, com busca por título, artista ou álbum, ordenação e índice alfabético.
- Atualização da biblioteca ao abrir o app, voltar a ele ou puxar a lista para baixo. Também há um botão para atualizar.
- Reprodução local em segundo plano, miniplayer, fila editável, avanço na faixa, modo aleatório e repetição de uma faixa ou da fila.
- Controles na notificação e na tela bloqueada, com capa nas cores originais e botão X para parar a reprodução. O sistema define a cor do cartão.
- Restauração da fila e da posição ao reabrir, com início da reprodução sob comando do usuário.
- Criação e edição de playlists, com seleção múltipla de faixas, reordenação e capa escolhida entre as músicas da lista.
- Favoritos, faixas adicionadas recentemente, histórico e músicas mais ouvidas.
- Player com as abas **Música**, **Letra** e **Significado**, temporizador para pausar e opções de aparência.
- Tema escuro azul-marinho e preto, com opção de fundo mais escuro, capa no fundo e ajuste do tamanho do texto.

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
