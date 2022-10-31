
locals {
  be-parts  = split( "/", var.backend-ref )
  be-title  = ( "" == var.backend-ref ? "" :
    1 == length(local.be-parts) ? local.be-parts[0] :
    2 == length(local.be-parts) ? local.be-parts[1] :
      local.be-parts[ length(local.be-parts) - 1 ] )
  be-proj   = ( "" == var.backend-ref ? "" :
    1 == length(local.be-parts) ? local.project :
    2 == length(local.be-parts) ? local.be-parts[0] :
    "projects" == local.be-parts[0] ? local.be-parts[1] :
      "ERROR backend-ref has URL not starting with 'projects/' (${var.backend-ref})" )
}

data "google_compute_backend_service" "b" {
  project   = local.be-proj
  name      = local.be-title
}

locals {
  be-id     = [ for id in [ data.google_compute_backend_service.b.id ] :
    try( 0 < length(id), false ) ? id :
      "ERROR No such backend as ${local.be-proj}/${local.be-title}" ][0]

  host-redir-code   = (
      301 == var.bad-host-redir ? "MOVED_PERMANENTLY_DEFAULT"
    : 302 == var.bad-host-redir ? "FOUND"
    : 303 == var.bad-host-redir ? "SEE_OTHER"
    : 307 == var.bad-host-redir ? "TEMPORARY_REDIRECT"
    : 308 == var.bad-host-redir ? "PERMANENT_REDIRECT"
    : "ERROR Invalid redirect HTTP status code: ${var.bad-host-redir}" )
  reroute       = "" != var.bad-host-backend
  reject        = ( ! local.reroute &&
    "EXTERNAL_MANAGED" == var.lb-scheme && 0 != var.bad-host-code )
  redirect      = ( ! local.reroute &&
    "EXTERNAL" == var.lb-scheme && "" != var.bad-host-host )
  check-host = local.reject || local.reroute || local.redirect

  honeypot-err  = ( ! var.exclude-honeypot ? "" :
    "" != var.url-map-ref ?
      "ERROR exclude-honeypot=true requires url-map-ref to be \"\"" :
    length(var.hostnames) < 2 ?
      "ERROR exclude-honeypot=true requires at least 2 hostnames" :
    var.lb-scheme == "EXTERNAL" && var.bad-host-host == ""
        && var.bad-host-backend == "" ?
      "ERROR exclude-honeypot=true requires bad-host-host or bad-host-backend" :
    var.lb-scheme == "EXTERNAL_MANAGED" && var.bad-host-code == 0 ?
      "ERROR exclude-honeypot=true cannot work with bad-host-code=0" : "" )

  skip-honeypot = ( var.exclude-honeypot && "" == local.honeypot-err )

  url-hosts     = [
    for h, fq in local.tofq : fq
    if fq != local.tofq[local.keys[0]] || ! local.skip-honeypot ]
}

# Maybe create a generic URL Map:
resource "google_compute_url_map" "u" {
  count     = var.url-map-ref != "" || var.lb-scheme == "" ? 0 : 1
  name      = "${var.name-prefix}url-map"

  project       = local.project
  description   = var.description
# labels        = var.labels

  dynamic "default_route_action" {
    for_each = toset( local.reject ? [1] : [] )
    content {
      fault_injection_policy {
        abort {
          http_status   = var.bad-host-code
          percentage    = 100
        }
      }
      weighted_backend_services {
        backend_service = local.be-id
      }
    }
  }

  dynamic "default_url_redirect" {
    for_each = toset( local.redirect ? [1] : [] )
    content {
      https_redirect            = true
      host_redirect             = var.bad-host-host
      path_redirect             = var.bad-host-path
      strip_query               = true
      redirect_response_code    = local.host-redir-code
    }
  }

  default_service               = ( local.reroute ? var.bad-host-backend
    : local.check-host ? null : local.be-id )

  dynamic "host_rule" {
    for_each = toset( local.check-host ? [1] : [] )
    content {
      hosts             = local.url-hosts
      path_matcher      = "svc"
    }
  }
  dynamic "path_matcher" {
    for_each = toset( local.check-host ? [1] : [] )
    content {
      name              = "svc"
      default_service   = local.be-id
    }
  }
}

locals {
  url-map-id = ( "" != local.honeypot-err ? local.honeypot-err :
    var.url-map-ref == "" && var.lb-scheme != "" ?
      google_compute_url_map.u[0].id : var.url-map-ref )
}

