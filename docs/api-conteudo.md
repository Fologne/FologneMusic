# API de letras e significados

O Django recebe título, artista e, quando disponíveis, álbum e duração. As rotas usam JSON. A reprodução local independe dessas rotas.

## Resolver uma faixa

`POST /api/v1/tracks/resolve/`

```json
{"title":"Usseewa","artist":"Ado","album":"Kyōgen","duration_ms":202000}
```

`title` e `artist` são obrigatórios. Envie a duração em milissegundos ou omita se for desconhecida. A API compara título e artista, usa álbum e duração para separar gravações e retorna:

| Campo | Uso |
| --- | --- |
| `status` | `matched`, `ambiguous` (mais de uma gravação ou duração incerta), `identity_ambiguous` (pares diferentes de título e artista), `not_found`, `unavailable` ou `provider_rate_limited` |
| `match` | Gravação confirmada ou `null` |
| `candidates` | Até 10 gravações para escolha manual em caso de ambiguidade |
| `metadata_match` | Referência para buscar significado pelos metadados enviados, mesmo sem uma gravação confirmada |

Cada referência contém `id`, `track_key` e `track`. Passe o `id` para as consultas de conteúdo. É um token assinado, legível por quem o possui, com validade de 24 horas. Use `track_key` como chave estável para conteúdo offline que a fonte permita salvar.

A resolução remove etiquetas conhecidas de vídeo e normaliza canais. Também testa pares de título e artista quando ambos estão no nome do arquivo. Divergências de duração e identidades ambíguas exigem escolha manual.

## Consultar conteúdo

- `GET /api/v1/tracks/{id}/lyrics/` consulta a gravação confirmada ou escolhida.
- `GET /api/v1/tracks/{id}/meaning/?language=pt-BR` consulta comentário editorial com fonte ou um link de contexto. A busca de links suporta português e inglês.

O corpo inclui `schema_version`, `status`, `language`, `text`, `source` e `fetched_at`. A letra original pode incluir `synced_lrc`. O LRCLIB não indica o idioma de forma confiável, então `language` fica nulo. A API de significado inclui `kind` quando encontra comentário ou contexto.

```json
{
  "schema_version": 1,
  "status": "link_only",
  "language": "en",
  "text": null,
  "source": {
    "name": "Wikipédia",
    "title": "Título do artigo",
    "url": "https://en.wikipedia.org/?curid=42",
    "offline_allowed": false
  },
  "fetched_at": "2026-11-06T12:00:00+00:00",
  "kind": "encyclopedic_context"
}
```

| HTTP | Situação |
| --- | --- |
| 200 | Estado do recurso. Pode ser `found`, `not_found`, `not_resolved`, `instrumental`, `link_only` ou `language_unavailable`. Na resolução, falhas do LRCLIB também retornam 200 com uma referência para buscar significado. |
| 400 | Dados de entrada inválidos. |
| 404 | Token desconhecido ou inválido. |
| 410 | Token expirado. Resolva novamente. |
| 429 | Limite local de consultas atingido. |
| 503 | Provedor indisponível ou com limite atingido, distinguido no campo `status`. |

A etapa 7 deve usar `source.offline_allowed` como condição para oferecer download de texto e preservar a referência da fonte no arquivo. Uma resposta `link_only` deve oferecer acesso ao link.

## Execução

Defina `MUSICAPP_USER_AGENT` com o nome do app e um contato real para produção. A API usa destinos fixos, timeout de socket de quatro segundos e limite de resposta de 512 KiB. O cache em memória guarda metadados e links por cinco minutos e buscas sem resultado por um minuto. Letras ficam fora desse cache. O limite local é de 20 chamadas às rotas de faixa por minuto por IP e por processo Django.

Para uma instalação pública com vários processos, configure um limite compartilhado no proxy ou na infraestrutura do servidor. Configure também a política de logs para o token da faixa, que inclui título, artista e outros metadados.
