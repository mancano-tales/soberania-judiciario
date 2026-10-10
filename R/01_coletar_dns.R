# =============================================================================
# 01_coletar_dns.R
# -----------------------------------------------------------------------------
# PT: Consulta os registros MX (quem recebe o e-mail) e TXT/SPF (quem pode
#     enviar em nome do domínio) de cada tribunal, usando o DNS público do
#     Google via HTTPS (DNS-over-HTTPS). Não precisa de `dig` instalado e
#     funciona igual em Windows, macOS e Linux.
# EN: Queries MX (who receives mail) and TXT/SPF (who may send on the
#     domain's behalf) records for each court, via Google's public
#     DNS-over-HTTPS resolver. No `dig` needed; works on any OS.
#
# Entrada / Input : data/dominios/dominios_*.csv  (pais, instituicao, ramo, dominio)
# Saída / Output  : data/resultados/provedores_<data>.csv
# =============================================================================

library(tidyverse)
library(httr2)

# -----------------------------------------------------------------------------
# 1. Consulta DNS via DoH / DNS lookup via DoH
# -----------------------------------------------------------------------------
# PT: Devolve um vetor de strings com as respostas do tipo pedido.
#     Tipos numéricos do DNS: MX = 15, TXT = 16.
# EN: Returns a character vector with the answers of the requested type.
consultar_dns <- function(dominio, tipo = c("MX", "TXT")) {
  tipo   <- match.arg(tipo)
  codigo <- c(MX = 15L, TXT = 16L)[[tipo]]

  resposta <- request("https://dns.google/resolve") |>
    req_url_query(name = dominio, type = tipo) |>
    req_retry(max_tries = 3) |>                 # tenta de novo se falhar / retry on failure
    req_perform() |>
    resp_body_json()

  # PT: `Answer` não existe quando o domínio não tem registro desse tipo.
  # EN: `Answer` is absent when the domain has no record of that type.
  respostas <- resposta$Answer %||% list()

  respostas |>
    keep(\(r) r$type == codigo) |>
    map_chr(\(r) r$data)
}

# -----------------------------------------------------------------------------
# 2. Classificação do provedor / Provider classification
# -----------------------------------------------------------------------------
# PT: Primeiro olha o MX. Se o MX aponta para um gateway (filtro antispam ou
#     servidor próprio), usa o SPF para inferir o provedor que está "atrás".
# EN: Look at MX first. If MX points to a gateway (spam filter or own
#     server), use SPF to infer the provider behind it.
classificar_provedor <- function(mx, spf) {
  case_when(
    str_detect(mx, regex("google|googlemail", ignore_case = TRUE))      ~ "Google",
    str_detect(mx, regex("outlook|microsoft", ignore_case = TRUE))      ~ "Microsoft",
    mx == ""                                                            ~ "Sem MX",
    str_detect(spf, regex("protection\\.outlook", ignore_case = TRUE))  ~ "Microsoft",
    str_detect(spf, regex("_spf\\.google", ignore_case = TRUE))         ~ "Google",
    .default = "Publico/proprio (verificar)"   # revisar à mão / review manually
  )
}

# -----------------------------------------------------------------------------
# 3. Coleta / Collection
# -----------------------------------------------------------------------------
dominios <- list.files("data/dominios", pattern = "\\.csv$", full.names = TRUE) |>
  map(read_csv, show_col_types = FALSE) |>
  list_rbind()

coletar_um <- function(dominio) {
  Sys.sleep(0.2)   # PT: pausa educada / EN: polite pause
  mx  <- consultar_dns(dominio, "MX")
  txt <- consultar_dns(dominio, "TXT")

  tibble(
    # PT: guarda só o hostname, sem a prioridade ("10 mx.exemplo.com." -> "mx.exemplo.com")
    # EN: keep only the hostname, dropping the priority
    mx_destino = mx |> str_remove("^\\d+\\s+") |> str_remove("\\.$") |>
      sort() |> str_c(collapse = "; "),
    spf        = txt |> keep(\(t) str_detect(t, "v=spf1")) |> str_c(collapse = " ")
  )
}

resultados <- dominios |>
  mutate(dns = map(dominio, possibly(coletar_um, otherwise = tibble(mx_destino = NA, spf = NA)),
                   .progress = TRUE)) |>
  unnest(dns) |>
  mutate(
    data_coleta = Sys.Date(),
    provedor    = classificar_provedor(coalesce(mx_destino, ""), coalesce(spf, ""))
  ) |>
  relocate(data_coleta)

# PT: Um arquivo por data, para acompanhar mudanças ao longo do tempo.
# EN: One file per date, so changes can be tracked over time.
write_csv(resultados, str_glue("data/resultados/provedores_{Sys.Date()}.csv"))

resultados |> count(pais, provedor)
