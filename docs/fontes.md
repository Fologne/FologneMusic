# Viabilidade das fontes de conteúdo

Atualização de 06/11/2026. O Django consulta fontes reais. A integração das abas e o download no Android fazem parte da etapa 7.

## Letras

LRCLIB é o candidato inicial. Sua [documentação oficial](https://lrclib.net/docs) descreve pesquisa e obtenção de letras simples e sincronizadas. A documentação exige identificação do cliente e informa limites de requisição. Antes da integração final, definir um endereço de projeto ou contato real para identificar o cliente.

O script `backend/scripts/probe_sources.py` faz consultas de leitura, não salva letras e imprime apenas contagens e IDs. Uma pesquisa pode retornar várias gravações; a presença de resultados não confirma correspondência exata com o arquivo do celular.

| Artista | Música | Candidatos retornados | Com letra simples | Com sincronização |
| --- | --- | --- | --- | --- |
| Ado | うっせぇわ | 20 | 20 | 20 |
| Sabaton | The Red Baron | 20 | 20 | 19 |
| Кино | Кукушка | 20 | 20 | 20 |
| Legião Urbana | Tempo Perdido | 20 | 20 | 20 |

Resultados variam ao longo do tempo. O limite da pesquisa não representa o tamanho total do catálogo. Será necessário comparar artista, título, álbum e duração, mantendo seleção manual para casos ambíguos.

O backend devolve a letra original, a fonte e, quando disponível, o LRC. A documentação consultada não confirmou permissão geral para guardar as letras offline. Por isso, o contrato marca as letras do LRCLIB com `offline_allowed: false`. O cache do servidor guarda apenas metadados da busca, sem o texto da letra.

Em 06/11, o contrato Django foi testado com essas quatro faixas usando o LRCLIB real. A API encontrou candidatos em todos os casos e retornou letra após a seleção de um candidato. A amostra usou metadados digitados e não confirma a gravação de cada arquivo no aparelho.

## Significados

Genius é um candidato a avaliar. O acesso direto à [documentação oficial](https://docs.genius.com/) retornou HTTP 403 neste ambiente. Não foi possível validar contrato, credenciais, custos, cobertura da amostra ou autorização para cópia offline. Não foi feito scraping nem criada integração baseada em suposições.

O catálogo inicial contém textos próprios em português que podem ser salvos offline com a referência. Inclui [Usseewa](https://www.theguardian.com/music/2024/mar/11/ado-platinum-selling-pop-star-secret-identity-troxy-london), [The Red Baron](https://www.sabaton.net/discography/the-great-war/), [505](https://www.nme.com/blogs/nme-blogs/arctic-monkeys-nme-interview-2007-favourite-worst-nightmare-2307701) e [Asterisk](https://realsound.jp/2021/02/post-707602.html). O campo `kind` distingue comentários atribuídos ao artista de interpretações editoriais. A identificação de Asterisk aceita a grafia japonesa registrada no [catálogo oficial da Aniplex](https://www.aniplex.co.jp/lineup/bleach/products/detail/?id=980).

Para outras músicas, a [API do MediaWiki](https://www.mediawiki.org/wiki/Extension:TextExtracts) permite localizar um artigo em português ou inglês. O backend usa título e artista para filtrar páginas e devolve só um link de contexto quando identifica um único artigo plausível. Em teste real, obteve links para Usseewa em inglês e Tempo Perdido em português. A busca não encontrou contexto para Кукушка na edição portuguesa. O app deve apresentar o link como contexto enciclopédico. Os [termos da Wikimedia](https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use) definem regras para reutilização de textos e suas exceções.

## Pendências para integração

- Obter uma fonte ou autorização que permita salvar letras offline.
- Ampliar a cobertura de significado com textos verificáveis e permissão de cópia.
- Repetir a amostra usando metadados reais dos arquivos do aparelho.
- Integrar a seleção da gravação e o armazenamento dos textos permitidos no Flutter.

As duas abas continuam independentes. Consulte o [contrato da API](api-conteudo.md) para identificar os estados disponíveis e preservar fonte, idioma e data.
