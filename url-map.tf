
locals {
  be-parts = split( "/", var.backend-ref )
  be-title = ( "" == var.backend-ref ? "" :
    1 == length(local.be-parts) ? local.be-parts[0] :
    2 == length(local.be-parts) ? local.be-parts[1] :
      local.be-parts[ length(local.be-parts) - 1 ] )
  be-proj = ( "" == var.backend-ref ? "" :
    1 == length(local.be-parts) ? local.project :
    2 == length(local.be-parts) ? local.be-parts[0] :
    "projects" == local.be-parts[1] ? local.be-parts[2] :
      "backend-ref has URL not starting with '/projects/'" )
}

data "google_compute_backend_service" "b" {
  project   = local.be-proj
  name      = local.be-title
}

locals {
  be-id = [ for id in [ data.google_compute_backend_service.b.id ] :
    try( 0 < length(id), false ) ? id :
      "No such backend as ${local.be-proj}/${local.be-title}" ][0]

  host-redir-code = ( 301 == var.bad-host-redir ? "MOVED_PERMANENTLY_DEFAULT"
    : 302 == var.bad-host-redir ? "FOUND"
    : 303 == var.bad-host-redir ? "SEE_OTHER"
    : 307 == var.bad-host-redir ? "TEMPORARY_REDIRECT"
    : 308 == var.bad-host-redir ? "PERMANENT_REDIRECT"
    : "Invalid redirect HTTP status code: ${var.bad-host-redir}" )
  reject = ( "EXTERNAL_MANAGED" == var.lb-scheme && 0 != var.bad-host-code )
  redirect = ( "EXTERNAL" == var.lb-scheme && "" != var.bad-host-path )
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

  dynamic "host_rule" {
    for_each = toset( local.reject || local.redirect ? [1] : [] )
    content {
      hosts             = [ for h, fq in local.tofq : fq ]
      path_matcher      = "svc"
    }
  }
  dynamic "path_matcher" {
    for_each = toset( local.reject || local.redirect ? [1] : [] )
    content {
      name              = "svc"
      default_service   = local.be-id
    }
  }
}

locals {
  url-map-id = ( var.url-map-ref == "" && var.lb-scheme != ""
    ? google_compute_url_map.u[0].id : var.url-map-ref )
}

