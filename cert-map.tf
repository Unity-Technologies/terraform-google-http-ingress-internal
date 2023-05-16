
module "cert-map" {
  source            = (
    "github.com/Unity-Technologies/terraform-google-certificate-map-simple-internal" )
  count             = "" == var.map-name ? 0 : 1

  project           = local.project
  description       = var.description
  labels            = var.labels

  name-prefix       = var.name-prefix
  dns-zone-ref      = var.dns-zone-ref
  dns-ttl-secs      = var.dns-ttl-secs
  map-name1         = var.map-name
  hostnames1        = var.hostnames
  cert-ids          = var.map-cert-ids
}

locals {
  cert-map-id = [ for id in [
    "" == var.map-name ? var.cert-map-ref : module.cert-map[0].map-id1[0] ] :
      1 < length(split( "certificatemanager.googleapis.com", id ))
        ? id : "//certificatemanager.googleapis.com/${id}"
      if "" != id ]
}

