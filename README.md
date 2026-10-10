# Onde está o e-mail do Judiciário? Brasil × Alemanha

*Where is the judiciary's e-mail hosted? Brazil × Germany*

Este repositório mede, com dados públicos de DNS, se o e-mail institucional dos tribunais brasileiros e alemães está hospedado na nuvem de empresas americanas (Google, Microsoft) ou em infraestrutura estatal, e reúne uma base qualitativa de casos, políticas e literatura sobre soberania digital.

*This repository uses public DNS data to measure whether Brazilian and German courts' institutional e-mail is hosted in US companies' clouds (Google, Microsoft) or on state infrastructure, and keeps a qualitative database on digital sovereignty.*

**Motivação.** Em 2025, o Procurador-Chefe do Tribunal Penal Internacional perdeu acesso ao seu e-mail hospedado na Microsoft, bloqueio atribuído às sanções dos EUA (a Microsoft nega ter suspendido os serviços ao tribunal como instituição). Qual é a exposição dos tribunais nacionais a esse tipo de risco?

## Resultados preliminares (coleta de 10/10/2026, 19:55 UTC)

| | Brasil | Alemanha |
|---|---|---|
| Unidades medidas | 95 domínios: todos os 91 tribunais sob o CNJ, mais STF, CNJ, CJF e CSJT | 23 domínios: 7 tribunais federais e a administração da Justiça de 16 estados |
| Google | 54 | 0 |
| Microsoft | 38 | 0 |
| Infraestrutura estatal | 0 | 22 |
| Indeterminado | 3 | 1 |

Confiança da classificação no Brasil: 82 alta (MX direto no provedor), 5 média e 5 baixa (e-mail recebido por um filtro intermediário; provedor inferido por DKIM, autodiscover ou SPF). Ver `docs/codebook.md`.

## O que estes dados mostram e o que não mostram

- **Mostram onde fica a caixa de entrada** de cada domínio: na nuvem de uma empresa americana ou em servidores do Estado.
- **Não mostram** contratos, onde ficam arquivos e documentos, quem controla as chaves de criptografia nem qual software roda nos servidores estatais. Os relatórios estaduais de TI da Justiça alemã mostram, por exemplo, Windows e Microsoft Office nos postos de trabalho e, em alguns estados, o Microsoft Teams. O contraste medido é **nuvem americana × hospedagem estatal**, não "fornecedor americano × autonomia tecnológica".
- **O viés não tem direção conhecida.** Registros SPF podem superestimar o uso de um provedor (autorizações apenas para envio), e o MX pode subestimar (gateways que escondem o provedor).
- **As unidades não são equivalentes.** O Brasil tem 91 tribunais sob o CNJ, cada um com autonomia administrativa e domínio próprio. A Alemanha tem cerca de 1.092 tribunais (CEPEJ, dados de 2021), cuja TI é organizada no nível de cada estado, como confirmam os relatórios estaduais de TI da Justiça (`qualitativo/blk_laenderberichte.csv`). Ainda não medimos os tribunais alemães que têm domínio próprio (ver issue #1).

## Estrutura

```
data/
  dominios/               listas de domínios (entrada)
  resultados/             uma coleta por data e hora, com as evidências de cada domínio
  correcoes_manuais.csv   classificações feitas à mão, com justificativa
  bruto/                  respostas DNS completas em JSON (geradas pelo script)
R/
  01_coletar_dns.R        coleta, salva o bruto, classifica e aplica as correções manuais
qualitativo/
  fontes.csv              casos, políticas, literatura e achados, cada um com fonte
docs/
  codebook.md             variáveis e regras de classificação
```

## Como reproduzir

```r
# install.packages(c("tidyverse", "httr2", "jsonlite"))
source("R/01_coletar_dns.R")
```

A coleta de 10/10/2026 foi feita com as mesmas consultas e regras do script, executadas no navegador. Ela publica as evidências extraídas, não o JSON bruto. As próximas coletas, feitas pelo script, salvam o bruto em `data/bruto/`.

## Autores

Giulia Melo e Tales Mançano (USP).

## Licença

Código: MIT. Dados e textos: CC BY 4.0.
