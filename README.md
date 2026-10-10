# Soberania digital do Judiciário: Brasil × Alemanha

*Digital sovereignty of the judiciary: Brazil × Germany*

Quem hospeda o e-mail institucional dos tribunais? Este repositório mede, com dados públicos de DNS, se os tribunais brasileiros e alemães dependem de provedores estrangeiros (Google, Microsoft) ou de infraestrutura pública própria, e reúne uma base qualitativa de casos, políticas e literatura sobre o tema.

*Who hosts courts' institutional e-mail? This repository uses public DNS data to measure whether Brazilian and German courts rely on foreign providers (Google, Microsoft) or on their own public infrastructure, and keeps a qualitative database of cases, policies and literature.*

**Motivação.** Em 2025, o Procurador-Chefe do Tribunal Penal Internacional perdeu acesso ao seu e-mail hospedado na Microsoft, bloqueio atribuído às sanções dos EUA (a Microsoft nega ter suspendido os serviços ao tribunal como instituição). Se isso aconteceu com um tribunal internacional, qual é a exposição dos tribunais nacionais?

## Primeiros resultados (coleta de 10/10/2026)

| | Brasil (95 tribunais e conselhos) | Alemanha (7 federais + 16 Länder) |
|---|---|---|
| Google | 54 | 0 |
| Microsoft | 38 | 0 |
| Infraestrutura pública | 0 | 22 |
| Indeterminado | 3 | 1 |

## Estrutura

```
data/
  dominios/     listas de domínios (entrada) / domain lists (input)
  resultados/   uma coleta por data / one snapshot per date
R/
  01_coletar_dns.R   coleta MX + SPF via DNS-over-HTTPS e classifica
qualitativo/
  fontes.csv    base qualitativa: casos, políticas, literatura, achados
docs/
  codebook.md   definição das variáveis e regras de classificação
```

## Como reproduzir

```r
# install.packages(c("tidyverse", "httr2"))
source("R/01_coletar_dns.R")
```

## Método, em uma linha

O registro **MX** de um domínio diz qual servidor recebe o e-mail; o registro **SPF** diz quais serviços podem enviar em nome dele. Quando o MX aponta para um filtro intermediário (*gateway*), o provedor é inferido pelo SPF. Ver `docs/codebook.md`.

**Limite:** o MX mostra onde está o e-mail, não onde estão arquivos e ferramentas de escritório. Os resultados são um limite inferior da dependência.

## Autores

Giulia Melo e Tales Mançano (USP).

## Licença

Código: MIT. Dados e textos: CC BY 4.0.
