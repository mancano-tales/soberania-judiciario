# Codebook

## `data/resultados/provedores_<data>T<hora>Z.csv`

| Variável | Descrição |
|---|---|
| `data_hora`, `resolver` | Momento da coleta (UTC) e resolver DNS usado |
| `pais` | `BR` ou `DE` |
| `instituicao`, `ramo` | Tribunal ou órgão e ramo da Justiça |
| `dominio` | Domínio que efetivamente recebe e-mail (nem sempre é o do site) |
| `dns_status` | Status da resposta DNS (0 = sem erro) |
| `mx_primario` | Servidor de e-mail de menor número de prioridade (o preferido) |
| `spf_google`, `spf_microsoft` | O SPF, expandido recursivamente (`include:` e `redirect=`), autoriza Google ou Microsoft a enviar |
| `token_ms`, `token_google` | Há token de verificação de domínio (`MS=…`, `google-site-verification`) |
| `dkim_microsoft` | `selector1._domainkey` aponta para `onmicrosoft.com` |
| `dkim_google` | Existe a chave `google._domainkey` |
| `autodiscover_microsoft` | `autodiscover.<domínio>` aponta para `outlook.com` |
| `provedor` | `Google`, `Microsoft`, `Publico` (infraestrutura estatal) ou `Indeterminado` |
| `confianca` | `alta`, `media` ou `baixa` |
| `regra` | Regra que produziu a classificação |

## Regras de classificação

Aplicadas na ordem; a primeira que se aplica decide.

- **R0.** Falha na consulta ou domínio sem MX → `Erro DNS` ou `Sem MX`.
- **R1.** MX primário em `aspmx.l.google.com`, `smtp.google.com` ou `googlemail.com` → **Google, alta**. MX primário em `mail.protection.outlook.com`, `mail.eo.outlook.com` ou `mx.microsoft` → **Microsoft, alta**.
- **R2.** MX em gateway (filtro antispam ou servidor intermediário) e evidência forte de serviço de caixa postal: DKIM ou autodiscover da Microsoft → **Microsoft, média**; DKIM do Google com SPF do Google → **Google, média**.
- **R3.** Gateway e apenas o SPF aponta para um provedor → esse provedor, **baixa**.
- **R4.** MX em infraestrutura governamental, sem Google ou Microsoft em SPF, DKIM ou autodiscover → **Publico, média**. Só é aplicada por correção manual justificada (`data/correcoes_manuais.csv`), porque exige identificar o operador.
- **R5.** Nenhuma evidência → **Indeterminado**.

**Tokens de verificação não entram nas regras.** Na coleta de 10/10/2026, o token `MS=` apareceu em dezenas de domínios cujo e-mail está no Google, e em vários domínios alemães sem nenhum outro sinal de Microsoft. Ele indica apenas que o domínio foi verificado em algum serviço da Microsoft (Teams, Azure etc.), não onde está a caixa postal.

## Unidade de análise

- **Brasil:** cada tribunal tem domínio próprio sob `.jus.br`. Cobertura: os 91 tribunais sob o CNJ (27 TJs, 6 TRFs, 24 TRTs, 27 TREs, 3 TJMs estaduais, STJ, TST, TSE e STM), mais STF, CNJ, CJF e CSJT.
- **Alemanha:** tribunais federais têm domínio próprio (rede `bund.de`); a Justiça estadual em geral usa a infraestrutura de TI do Land, e a unidade medida é o domínio da administração da Justiça de cada estado. Tribunais estaduais com domínio próprio ainda não foram medidos. `berlin.de` é o domínio de toda a administração de Berlim, não específico da Justiça.

## `qualitativo/fontes.csv`

| Variável | Descrição |
|---|---|
| `id` | `Q001`, `Q002`… |
| `tipo` | `caso`, `artigo`, `politica`, `projeto`, `contrato`, `noticia`, `achado` |
| `url` | Fonte conferida (para achados próprios, o arquivo de dados) |
| `relevancia` | Por que importa para o argumento |
| `tags` | Separadas por `;` |

Só entram na base informações conferidas na fonte indicada na coluna `url`. Hipóteses ficam fora até serem verificadas.
