# =============================================================================
# 01_coletar_dns.R
# -----------------------------------------------------------------------------
# PT: Coleta registros DNS de cada domínio (MX, TXT/SPF, DKIM, autodiscover)
#     via DNS-over-HTTPS do Google, salva o BRUTO em JSON e aplica as regras
#     de classificação descritas em docs/codebook.md. Nenhuma edição manual:
#     correções justificadas ficam em data/correcoes_manuais.csv e são
#     aplicadas por último, de forma explícita.
# EN: Collects DNS records per domain (MX, TXT/SPF, DKIM, autodiscover) via
#     Google DNS-over-HTTPS, stores RAW JSON, and applies the rules in
#     docs/codebook.md. No hand edits: justified overrides live in
#     data/correcoes_manuais.csv and are applied last, explicitly.
#
# Entrada / Input : data/dominios/dominios_*.csv  (pais, instituicao, ramo, dominio)
# Saídas / Output : data/bruto/dns_<timestamp>.json
#                   data/resultados/provedores_<timestamp>.csv
# =============================================================================

library(tidyverse)
library(httr2)
library(jsonlite)

carimbo  <- format(Sys.time(), "%Y-%m-%dT%H%MZ", tz = "UTC")  # data e hora UTC / UTC timestamp
resolver <- "https://dns.google/resolve"

# -----------------------------------------------------------------------------
# 1. Consulta DNS / DNS query
# -----------------------------------------------------------------------------
# PT: Devolve status (0 = NOERROR, 3 = NXDOMAIN, 2 = SERVFAIL, NA = erro HTTP)
#     e as respostas brutas (tipo + dado). Não esconde falhas.
# EN: Returns status and raw answers. Failures are recorded, not hidden.
consultar <- function(nome, tipo) {
  resp <- tryCatch(
    request(resolver) |>
      req_url_query(name = nome, type = tipo) |>
      req_retry(max_tries = 4, is_transient = \(r) resp_status(r) == 429) |>
      req_perform() |>
      resp_body_json(),
    error = \(e) NULL
  )
  if (is.null(resp)) return(list(status = NA_integer_, respostas = list()))
  list(
    status    = resp$Status,
    respostas = map(resp$Answer %||% list(), \(a) list(tipo = a$type, dado = a$data))
  )
}

# PT: Extrai os textos de registros TXT (tipo 16), juntando segmentos "a" "b".
# EN: Extract TXT strings (type 16), joining split segments.
textos_txt <- function(consulta) {
  consulta$respostas |>
    keep(\(a) a$tipo == 16) |>
    map_chr(\(a) a$dado |> str_remove_all('"\\s*"') |> str_remove_all('^"|"$'))
}

# PT: Resolve o SPF recursivamente (include: e redirect=), até 4 níveis.
#     Mecanismos já reconhecíveis (Google, Microsoft) não são expandidos.
# EN: Recursively expand SPF (include:/redirect=), up to depth 4.
spf_expandido <- function(dominio, nivel = 0, vistos = character()) {
  if (nivel > 4 || dominio %in% vistos) return("")
  spf <- textos_txt(consultar(dominio, "TXT")) |>
    keep(\(t) str_detect(t, regex("^v=spf1", ignore_case = TRUE))) |>
    first(default = "")
  alvos <- str_match_all(spf, "(?:include:|redirect=)(\\S+)")[[1]][, 2]
  alvos <- alvos[!str_detect(alvos, "google|outlook")]
  filhos <- map_chr(alvos, \(a) spf_expandido(a, nivel + 1, c(vistos, dominio)))
  str_c(c(spf, filhos), collapse = " ")
}

# -----------------------------------------------------------------------------
# 2. Coleta por domínio / Per-domain collection
# -----------------------------------------------------------------------------
coletar <- function(dominio) {
  Sys.sleep(0.1)  # pausa educada / polite pause
  list(
    dominio       = dominio,
    carimbo       = carimbo,
    resolver      = resolver,
    mx            = consultar(dominio, "MX"),
    txt           = consultar(dominio, "TXT"),
    spf_expandido = spf_expandido(dominio),
    dkim_ms       = consultar(str_c("selector1._domainkey.", dominio), "CNAME"),
    dkim_google   = consultar(str_c("google._domainkey.", dominio), "TXT"),
    autodiscover  = consultar(str_c("autodiscover.", dominio), "CNAME")
  )
}

dominios <- list.files("data/dominios", pattern = "\\.csv$", full.names = TRUE) |>
  map(read_csv, show_col_types = FALSE) |>
  list_rbind()

bruto <- map(dominios$dominio, coletar, .progress = TRUE)

dir.create("data/bruto", showWarnings = FALSE)
write_json(bruto, str_glue("data/bruto/dns_{carimbo}.json"), auto_unbox = TRUE, pretty = TRUE)

# -----------------------------------------------------------------------------
# 3. Evidências / Evidence
# -----------------------------------------------------------------------------
# PT: MX primário = o de MENOR número de prioridade (o servidor preferido).
# EN: Primary MX = lowest preference value.
mx_primario <- function(consulta) {
  consulta$respostas |>
    keep(\(a) a$tipo == 15) |>
    map(\(a) str_split_1(a$dado, " ")) |>
    map(\(p) tibble(prioridade = as.integer(p[1]), host = str_remove(tolower(p[2]), "\\.$"))) |>
    list_rbind() |>
    arrange(prioridade) |>
    pull(host) |>
    first(default = "")
}

tem <- function(x, padrao) str_detect(str_c(x, collapse = " "), regex(padrao, ignore_case = TRUE))

evidencias <- map(bruto, \(b) {
  txt <- textos_txt(b$txt)
  tibble(
    dominio                = b$dominio,
    dns_status             = b$mx$status,
    mx_primario            = mx_primario(b$mx),
    spf_google             = tem(b$spf_expandido, "_spf\\.google\\.com"),
    spf_microsoft          = tem(b$spf_expandido, "spf\\.protection\\.outlook\\.com"),
    # PT: tokens de verificação são evidência FRACA (aparecem até em domínios
    #     hospedados no concorrente); registrados, mas não usados na regra.
    # EN: verification tokens are WEAK evidence; recorded, not used in rules.
    token_ms               = any(str_detect(txt, "^MS=")),
    token_google           = any(str_detect(txt, "google-site-verification")),
    dkim_microsoft         = tem(map_chr(b$dkim_ms$respostas, "dado"), "onmicrosoft\\.com"),
    dkim_google            = length(textos_txt(b$dkim_google)) > 0,
    autodiscover_microsoft = tem(map_chr(b$autodiscover$respostas, "dado"), "outlook\\.com")
  )
}) |> list_rbind()

# -----------------------------------------------------------------------------
# 4. Regras de classificação (ver docs/codebook.md) / Classification rules
# -----------------------------------------------------------------------------
mx_google    <- "(aspmx\\.l\\.google\\.com|smtp\\.google\\.com|googlemail\\.com)$"
mx_microsoft <- "(mail\\.protection\\.outlook\\.com|mail\\.eo\\.outlook\\.com|mx\\.microsoft)$"

resultados <- dominios |>
  left_join(evidencias, by = "dominio") |>
  mutate(
    forte_ms     = dkim_microsoft | autodiscover_microsoft,
    classificado = case_when(
      is.na(dns_status) | dns_status != 0                         ~ "Erro DNS|—|R0: falha na consulta",
      mx_primario == ""                                           ~ "Sem MX|—|R0: domínio sem MX",
      str_detect(mx_primario, mx_google)                          ~ "Google|alta|R1: MX primário no Google",
      str_detect(mx_primario, mx_microsoft)                       ~ "Microsoft|alta|R1: MX primário na Microsoft",
      forte_ms & !dkim_google                                     ~ "Microsoft|media|R2: gateway + DKIM/autodiscover Microsoft",
      dkim_google & !forte_ms & spf_google                        ~ "Google|media|R2: gateway + DKIM Google + SPF Google",
      spf_microsoft & !spf_google                                 ~ "Microsoft|baixa|R3: gateway + apenas SPF Microsoft",
      spf_google & !spf_microsoft                                 ~ "Google|baixa|R3: gateway + apenas SPF Google",
      # PT: R4 (público) só com operador confirmado — feito via correções manuais.
      # EN: R4 (public) only with a confirmed operator — via manual overrides.
      .default                                                    ~ "Indeterminado|—|R5: sem evidência de provedor"
    )
  ) |>
  separate_wider_delim(classificado, "|", names = c("provedor", "confianca", "regra")) |>
  select(-forte_ms)

# -----------------------------------------------------------------------------
# 5. Correções manuais explícitas / Explicit manual overrides
# -----------------------------------------------------------------------------
# PT: Cada linha tem domínio, provedor, confiança, regra e justificativa com fonte.
# EN: Each row: domain, provider, confidence, rule, justification with source.
correcoes <- read_csv("data/correcoes_manuais.csv", show_col_types = FALSE)

resultados <- resultados |>
  rows_update(correcoes |> select(dominio, provedor, confianca, regra),
              by = "dominio", unmatched = "ignore") |>
  mutate(data_hora = carimbo, resolver = "dns.google", .before = 1)

write_csv(resultados, str_glue("data/resultados/provedores_{carimbo}.csv"))

resultados |> count(pais, provedor, confianca)
