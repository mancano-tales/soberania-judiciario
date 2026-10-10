# Codebook

## `data/resultados/provedores_<data>.csv`

| Variável | Descrição |
|---|---|
| `data_coleta` | Data da consulta DNS |
| `pais` | `BR` ou `DE` |
| `instituicao` | Sigla ou nome do tribunal / órgão |
| `ramo` | BR: Superior, Conselho, Federal, Trabalho, Eleitoral, Estadual, Militar estadual. DE: Federal, Estadual |
| `dominio` | Domínio que efetivamente recebe e-mail (nem sempre é o do site) |
| `mx_destino` | Para onde aponta o registro MX |
| `spf_autoriza` | Se o SPF autoriza Google e/ou Microsoft a enviar |
| `provedor` | `Google`, `Microsoft`, `Publico` (infraestrutura pública ou própria) ou `Indeterminado` |

## Regras de classificação

1. MX aponta para `google.com` / `googlemail.com` → **Google**.
2. MX aponta para `outlook.com` / `microsoft` → **Microsoft**.
3. MX aponta para gateway (antispam próprio, Trend Micro, FireEye etc.):
   - SPF inclui `spf.protection.outlook.com` → **Microsoft**
   - SPF inclui `_spf.google.com` → **Google**
   - Nenhum dos dois → **Indeterminado** (verificação manual)
4. MX em infraestrutura governamental ou da própria instituição, sem Google/Microsoft no SPF → **Publico**.

## Unidade de análise

- **Brasil:** cada tribunal tem domínio próprio sob `.jus.br`.
- **Alemanha:** tribunais federais têm domínio próprio (rede `bund.de`); a Justiça estadual em geral compartilha a infraestrutura do Land, então a unidade é a Justiça de cada estado. Tribunais estaduais testados individualmente (OLG Köln, OLG Hamm, OLG Stuttgart, OLG München) seguem o mesmo padrão.

## `qualitativo/fontes.csv`

| Variável | Descrição |
|---|---|
| `id` | `Q001`, `Q002`… |
| `tipo` | `caso`, `artigo`, `politica`, `projeto`, `contrato`, `noticia`, `achado` |
| `relevancia` | Por que importa para o argumento |
| `tags` | Separadas por `;` |

Só entram na base informações conferidas na fonte indicada na coluna `url`. Hipóteses ficam fora até serem verificadas.
