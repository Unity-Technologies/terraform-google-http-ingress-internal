
locals {
  ip-parts  = split( "/", var.ip-addr-ref )
  ip-str    = (
       1 == length(local.ip-parts)
    && 1 < length(split( ".", var.ip-addr-ref ))
      ? var.ip-addr-ref : "" )
  ip-proj   = ( local.ip-str != "" ? ""
    : 1 == length(local.ip-parts)
    ? local.project : local.ip-parts[0] )
  ip-title  = ( local.ip-str != "" ? ""
    : 1 == length(local.ip-parts)
    ? local.ip-parts[0] : local.ip-parts[1] )
}

# Look up an IP Address allocated elsewhere:
data "google_compute_global_address" "i" {
  count     = local.ip-title == "" ? 0 : 1
  name      = local.ip-title
  project   = local.ip-proj
}

# OR Allocate an IP Address:
resource "google_compute_global_address" "i" {
  count         = var.ip-addr-ref == "" ? 1 : 0
  name          = "${var.name-prefix}ip"
  project       = local.project
  description   = var.description
  labels        = var.labels
}

locals {
  ip-addr = (
    var.ip-addr-ref == ""
    ? google_compute_global_address.i[0].address
    : local.ip-str != "" ? local.ip-str
    : [ for ip in [ data.google_compute_global_address.i[0].address ] :
        try( "" != ip, false ) ? ip
        : "ERROR IP Addr ${local.ip-proj}/${local.ip-title} not found" ][0] )
}

