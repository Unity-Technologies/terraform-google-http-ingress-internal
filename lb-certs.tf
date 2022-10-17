
locals {
  lb-hosts = !var.create-lb-certs ? {} : {
    for h, suff in local.tosuff : h => local.tofq[h]
      if suff == "|LB" || suff == "" }
}

# GCP-Managed Cert:
resource "google_compute_managed_ssl_certificate" "c" {
  for_each  = local.lb-hosts
  name      = lower(replace( "${var.name-prefix}${each.key}", ".", "-"))
  type      = "MANAGED"

  project       = local.project
  description   = var.description
# labels        = var.labels

  managed {
    domains = [ each.value ]
  }
  lifecycle {
    # This prevents changes from recreating a cert but does nothing to
    # prevent a cert from being destroyed when you no longer ask for it.
    prevent_destroy = true
  }
}

locals {
  lb-cert-ids = [ for ref in var.lb-cert-refs : ref
    if 2 < length(split("/",ref)) ]

  lb-cert-parts = [ for ref in var.lb-cert-refs :
    2 == length(split("/",ref)) ? ref : "${local.project}/${ref}"
    if length(split("/",ref)) < 3 ]
}

data "google_compute_ssl_certificate" "c" {
  for_each  = toset( local.lb-cert-parts )
  project   = split( "/", each.value )[0]
  name      = split( "/", each.value )[1]
}

