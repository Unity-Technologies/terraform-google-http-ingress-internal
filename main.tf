
data "google_client_config" "default" {
}

terraform {
  required_version = ">= 0.13"
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = ">= 4.30"
    }
  }
}

locals {
  # Try to give a hint what failed if local.project ends up empty:
  project = ( "" != var.project ? var.project :
    [ for p in [ data.google_client_config.default.project ] :
        try( "" != p, false ) ? p
        : "ERROR google_client_config.default does not define '.project'" ][0] )
}

# The *.tf files of this module are evaulated in the following order:
#   variables.tf    # Declare Inputs to module
#   main.tf         # Providers and determine Project
#   ip.tf           # Allocate or reference an IP Address
#   dns.tf          # Reference zone, add DNS `A` records
#   lb-certs.tf     # Create "classic" certs
#   cert-map.tf     # Create "modern" certs and cert map
#   url-map.tf      # Create or reference URL Map
#   load-bal.tf     # Create forwarding rules and target proxies
#   outputs.tf      # Declare Outputs from module
