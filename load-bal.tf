
locals {
  with-https = var.lb-scheme != "" && (
    var.map-name != "" || var.cert-map-ref != "" || var.create-lb-certs
    || 0 < length(var.lb-cert-refs) )

  http-redir = ( 301 == var.http-redir-code ? "MOVED_PERMANENTLY_DEFAULT"
    : 302 == var.http-redir-code ? "FOUND"
    : 303 == var.http-redir-code ? "SEE_OTHER"
    : 307 == var.http-redir-code ? "TEMPORARY_REDIRECT"
    : 308 == var.http-redir-code ? "PERMANENT_REDIRECT"
    : "ERROR Invalid redirect HTTP status code: ${var.http-redir-code}" )
}

# HTTPS target proxy:
resource "google_compute_target_https_proxy" "https" {
  count     = local.with-https ? 1 : 0
  name      = "${var.name-prefix}https"
  url_map   = local.url-map-id

  project       = local.project
  description   = var.description
# labels        = var.labels

  quic_override     = var.quic-override
  certificate_map   = "" == local.cert-map-id[0] ? null : local.cert-map-id[0]
  ssl_certificates  = "" != local.cert-map-id[0] ? null : flatten( [
    [ for h, c in google_compute_managed_ssl_certificate.c : c.id ],
    local.lb-cert-ids,
    [ for ref, c in data.google_compute_ssl_certificate.c :
      try( 0 < length(c.id), false ) ? c.id
        : "ERROR No certificate ${ref} found" ],
  ] )
  # TODO: Add support for ssl_policy set from var.ssl-policy-ref
}

# URL Map to redirect from http:// to https://
resource "google_compute_url_map" "redir" {
  count         = local.with-https && var.redirect-http ? 1 : 0
  name          = "${var.name-prefix}redir"

  project       = local.project
  description   = var.description
# labels        = var.labels

  default_url_redirect {
    https_redirect          = true
    redirect_response_code  = local.http-redir
    strip_query             = false
  }
}

# HTTP target proxy:
resource "google_compute_target_http_proxy" "http" {
  count         = var.lb-scheme == "" ? 0 : 1
  name          = "${var.name-prefix}http"
  url_map       = ( local.with-https && var.redirect-http
    ? google_compute_url_map.redir[0].id : local.url-map-id )

  project       = local.project
  description   = var.description
# labels        = var.labels
}

# HTTPS listener:
resource "google_compute_global_forwarding_rule" "f443" {
  count         = local.with-https ? 1 : 0
  name          = "${var.name-prefix}f443"
  target        = google_compute_target_https_proxy.https[0].id
  ip_address    = local.ip-addr
  port_range    = "443"

  project       = local.project
  description   = var.description
  labels        = var.labels

  load_balancing_scheme = var.lb-scheme
}

# HTTP listener:
resource "google_compute_global_forwarding_rule" "f80" {
  count         = var.lb-scheme == "" ? 0 : 1
  name          = "${var.name-prefix}f80"
  target        = google_compute_target_http_proxy.http[0].id
  ip_address    = local.ip-addr
  port_range    = "80"

  project       = local.project
  description   = var.description
  labels        = var.labels

  load_balancing_scheme = var.lb-scheme
}

