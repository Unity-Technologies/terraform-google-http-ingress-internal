

###--- Required inputs ---###

variable "name-prefix" {
  description   = <<-EOD
    The prefix string to prepend to the `.name` of most of the GCP resources
    created by this module.

    Example: name-prefix = "my-svc-"
  EOD
  type          = string
}


###--- Most-used inputs ---###

variable "hostnames" {
  description   = <<-EOD
    The host name(s) used to connect to your backend.

    Any "short" hostname (one that contains no "." characters or has a
    final "." character) will have the domain referenced via `dns-zone-ref`
    appended to it.  [Note that the final "." here has the opposite meaning
    of a final "." character in some other DNS situations.]

    If a URL map is created and you list at least one hostname, then the URL
    map will (by default) only route requests for the listed hostname(s) to
    your backend.

    If you set `dns-add-hosts = true`, then each "short" hostname will have
    DNS `A` records created in the referenced GCP-Managed DNS Zone.

    If `map-name` is not blank, then a "modern" DNS-authorized certificate
    (by default) will be created for each hostname.  Those will all be
    placed into a certificate map.

    If you set `create-lb-certs = true`, then a "classic" LB-authorized
    certificate will be created (by default) for each hostname.

    Appending just "|" to a hostname prevents a certificate from being
    created.  Appending "|LB" means the certificate will be LB-authorized.
    Appending "|" followed by a numeric offset will use a certificate's
    `.id` from `map-cert-ids`.

    For more details:
    https://github.com/TyeMcQueen/terraform-google-https-ingress/docs/Usage.md#hostnames

    Example:
      hostnames     = [ "my-api", "web.my-product.example.com" ]

    Example:
      hostnames     = [ "honeypot", "svc.stg.|LB", "*.my-domain.com|0" ]
      map-cert-ids  = [
        google_certificate_manager_certificate.wild.id,
      ]
  EOD
  type          = list(string)
  default       = []
}


###--- Major options ---###

variable "create-lb-certs" {
  description   = <<-EOD
    Set to `true` to have a "classic" LB-authorized certificate created (by
    default) for each hostname in `hostnames`.  Each created certificate
    will be added to the Target HTTPS Proxy (if such is created).

    Hostnames ending in just "|" will have no certificate created for them
    (which usually means a certificate covering that hostname is provided
    via `lb-cert-refs`).  A "|LB" suffix on a hostname is ignored and other
    uses of "|" are not supported when `create-lb-certs` is `true`.
  EOD
  type          = bool
  default       = false
}

variable "map-name" {
  description   = <<-EOD
    The name of the certificate map to create.  If left as "", then no
    certificate map is created.

    If not "", then a DNS-authorized certificate is created (by default) for
    each hostname in `hostnames` and a certificate map entry is added for the
    hostname and pointing to that created certificate.  The entry for the
    first hostname will be "PRIMARY" (handed out if a request's hostname
    does not match any of the other entries).

    Hostnames that end in "|LB" have a "modern" LB-authorized certificate
    created for them instead.  Hostnames that end in just "|" have no
    certificate created and are not added to the certificate map.  Hostnames
    that end in "|" followed by a numeric offset will be added to the
    map using the certificate `.id` at that offset in `map-cert-ids` (no
    certificate is created).

    Example: map-name = "my-cert-map"
  EOD
  type          = string
  default       = ""
}

variable "lb-scheme" {
  description   = <<-EOD
    Defaults to "EXTERNAL_MANAGED" ["Modern" Global L7 HTTP(S) LB].  Can be
    set to "EXTERNAL" ["Classic" Global L7 HTTP(S) LB].  Or set to "" to
    deprovision most of the LB components so they can then be fully recreated.

    Switching between "EXTERNAL" and "EXTERNAL_MANAGED" may leave Terraform
    unable to automatically recreate the needed components in the proper
    order to successfully complete the transition.  If you switch to "" and
    apply and then switch to your desired value and apply again, then the
    reconstruction should work fine.  This will not remove components that
    do not need to be recreated, especially the allocated IP address and SSL
    certificate(s).
  EOD
  type          = string
  default       = "EXTERNAL_MANAGED"

  validation {
    condition       = ( var.lb-scheme == "" ||
      var.lb-scheme == "EXTERNAL" || var.lb-scheme == "EXTERNAL_MANAGED" )
    error_message   = "Must be \"EXTERNAL\", \"EXTERNAL_MANAGED\", or \"\"."
  }
}


###--- References to resources created elsewhere ---###

variable "dns-zone-ref" {
  description   = <<-EOD
    Either the name given to a GCP-Managed DNS Zone resource in this project,
    "$${project-id}/$${name}" for a DNS Zone in a different project, or blank
    to not use any of the below features.  [A full DNS Zone resource `.id`
    cannot be used here at this time.]

    If set, then you can use short names in `hostnames` ("api" for
    "api.my-domain.com" or "web.stg." for "web.stg.my-domain.com").
    If you also set `dns-add-hosts = true`, then DNS `A` records will
    be created for any short names in `hostnames`.

    WARNING: Trying to create duplicate DNS records is not currently
    detected by the GCP Terraform providers and can result in confusing
    flip-flopping of how the DNS record is defined each time the Terraform
    is applied.  So be sure to not create the same DNS record twice, once
    within this module and once outside of this module.

    If set, then you can create DNS-authorized certificates by also setting
    `map-name`.

    Examples:
      dns-zone-ref = "product-dns-zone"
      dns-zone-ref = google_dns_managed_zone.my-product.name
  EOD
  type          = string
  default       = ""

  validation {
    condition       = length(split( "/", var.dns-zone-ref )) < 3
    error_message   = "Can't be a full resource .id."
  }
}

variable "backend-ref" {
  description   = <<-EOD
    Either a full Backend Service resource `.id`, the `.name` given to a
    Backend Service resource in this project, "$${project-id}/$${name}"
    for a Backend Service in a different project, or "" if you provided
    `url-map-ref` instead.

    You must provide either `backend-ref` or `url-map-ref`.

    If your Backend Service is created in the same Terraform workspace,
    then be sure to reference the resource block when setting this
    parameter so the Backend will be created before this module is called.

    Example: backend-ref = google_compute_backend_service.my-be.id
  EOD
  type          = string
  default       = ""
}

variable "ip-addr-ref" {
  description   = <<-EOD
    Name given to a Public IP Address allocated elsewhere.  Leave
    blank to have one allocated.  The string can also be in the format
    "$${project-id}/$${name}" to use an IP Address allocated in a different
    GCP Project.  Or you can just set it to the actual IP address.  [A full
    resource `.id` cannot be used here.]
    Examples:
      ip-addr-ref = "api-ip"
      ip-addr-ref = "35.1.2.3"
  EOD
  type          = string
  default       = ""

  validation {
    condition       = length(split( "/", var.ip-addr-ref )) < 3
    error_message   = "Can't be a full resource .id."
  }
}

variable "cert-map-ref" {
  description   = <<-EOD
    The `.id` of a certificate map created outside of this module.
    [A future release may allow other types of references after
    `data "google_certificate_manager_certificate_map"` blocks are
    supported.]

    Examples:
      cert-map-ref = google_certificate_manager_certificate_map.my-cert-map.id
      cert-map-ref = module.my-cert-map.map1[0].id
  EOD
  type          = string
  default       = ""

  validation {
    condition       = ( "" == var.cert-map-ref
      || 2 < length(split( "/", var.cert-map-ref )) )
    error_message   = "Must be a full resource .id or \"\"."
  }
}

variable "map-cert-ids" {
  description   = <<-EOD
    List of `.id`s of Cloud Certificate Manager ("modern") SSL Certificates
    that can be referenced from `hostnames` to be included in the created
    certificate map.  Append "|" followed by the index (starting at 0) in
    this list of the certificate you want to use with that hostname.

    Example:
      map-cert-ids  = [
        google_certificate_manager_certificate.api.id,
        google_certificate_manager_certificate.web.id,
      ]
      hostnames     = [ "api|0", "web|1" ]
  EOD
  type          = list(string)
  default       = []
}

variable "lb-cert-refs" {
  description   = <<-EOD
    List of references to extra "classic" SSL Certificates to be added to
    the created Target HTTPS Proxy.  Each reference can be the name given
    to a Certificate resource in this project, "$${project-id}/$${name}" for
    a Cert in a different project, or just a full Cert resource `.id`.

    Example:
      lb-cert-refs = [ "my-api-cert",
        google_compute_managed_ssl_certificate.canary-api.id ]
  EOD
  type          = list(string)
  default       = []
}

variable "url-map-ref" {
  description   = <<-EOD
    Full resource path (`.id`) for a URL Map created elsewhere (or leave as
    "" to have a generic URL Map created).  [A future release may allow other
    types of references after `data "google_compute_url_map"` blocks are
    supported.]

    If `url-map-ref` is left blank, then you must provide `backend-ref`
    which will be used by the created URL Map.

    Example: url-map-ref = google_compute_url_map.api.id
  EOD
  type          = string
  default       = ""

  validation {
    condition       = ( "" == var.url-map-ref
      || 2 < length(split( "/", var.url-map-ref )) )
    error_message   = "Must be a full resource .id or \"\"."
  }
}


###--- Generic customization inputs ---###

variable "project" {
  description   = <<-EOD
    The ID of the GCP Project that most resources will be created in.
    Defaults to "" which uses the default project of the Google client
    configuration.  Any DNS resources will be created in the project
    that owns the GCP-Managed DNS Zone referenced by `dns-zone-ref`.

    Example: project = "my-gcp-project"
  EOD
  type          = string
  default       = ""
}

variable "description" {
  description   = <<-EOD
    An optional description to be used on every created resource (except
    DNS records which don't allow descriptions).

    Example: description = "Created by Terraform module http-ingress"
  EOD
  type          = string
  default       = ""
}

variable "labels" {
  description   = <<-EOD
    A map of label names and values to be applied to every created resource
    that supports labels (this includes the IP Address, the Forwarding Rules,
    the certificate map, and "modern" certificates).

    Example:
      labels = { team = "my-team", terraform = "my-workspace" }
  EOD
  type          = map(string)
  default       = {}
}


###--- Simple options ---###

variable "ip-is-shared" {
  description   = <<-EOD
    When `ip-addr-ref` is not blank, set `ip-is-shared = false` to
    still create the HTTP/S Target Proxies and Global Forwarding Rules.
    You would set `ip-is-shared = false` when re-using an IP Address
    allocated elsewhere but that is not used anywhere else.  Or when you
    actually are sharing the IP Address, in which case you would only
    set `ip-is-shared = false` for _one_ of the uses.
  EOD
  type          = bool
  default       = true
}


###--- DNS options ---###

variable "dns-add-hosts" {
  description   = <<-EOD
    Set to `true` to create DNS `A` records for each entry in `hostnames`
    that is "short" (contains no "." or ends in a  ".").
  EOD
  type          = bool
  default       = false
}

variable "dns-ttl-secs" {
  description   = <<-EOD
    Time-To-Live, in seconds, for created DNS records.
  EOD
  type          = number
  default       = 300
}


###--- HTTPS proxy options ---###

variable "quic-override" {
  description   = <<-EOD
    For the created https_target_proxy, whether to explicitly enable or
    disable negotiating QUIC optimizations with clients.  The default is
    "NONE" which uses the current default ("DISABLE" at the time of
    this writing).  Can be "ENABLE" or "DISABLE" (or "NONE").
  EOD
  type          = string
  default       = "NONE"

  validation {
    condition       = ( var.quic-override == "NONE" ||
      var.quic-override == "ENABLE" || var.quic-override == "DISABLE" )
    error_message   = "Must be \"NONE\", \"ENABLE\", or \"DISABLE\"."
  }
}

# TODO: ssl-policy-ref = ""


###--- HTTP-to-HTTPS redirect options ---###

variable "redirect-http" {
  description   = <<-EOD
    Set `redirect-http = false` to have http:// requests routed to your
    Backend.  By default, a separate URL Map is created for just http://
    requests that simply redirects to https://, but only if you create
    or reference at least one SSL certificate (otherwise https:// are
    not even supported).
  EOD
  type          = bool
  default       = true
}

variable "http-redir-code" {
  description   = <<-EOD
    The status code used when redirecting http:// requests to https://.  Only
    used if you leave `redirect-http` as `true` and create or reference at
    least one SSL certificate.  It can be 301, 302, 303, 307, or 308.  307
    is the default as mistakenly enabling the redirect using 308 can have
    long-lasting impacts that cannot be easily reverted.  Using any value
    other than 307 or 308 may cause the HTTP method to change to "GET".
  EOD
  type          = number
  default       = 307

  validation {
    condition       = (
         301 <= var.http-redir-code && var.http-redir-code <= 303
      || 307 == var.http-redir-code || 308 == var.http-redir-code )
    error_message   = "Must be 301, 302, 303, 307, or 308."
  }
}


###--- URL map options ---###

variable "exclude-honeypot" {
  description   = <<-EOD
    Set to `true` to not forward to your Backend any requests sent to the
    "honeypot" (first) hostname.  This can only work when there are at
    least 2 entries in `hostnames` and `url-map-ref` is not "".  If
    `lb-scheme` is left as "EXTERNAL_MANAGED", then `bad-host-code` must
    not be set to 0 (or `bad-host-backend` must not be "").  If `lb-scheme`
    is set to "EXTERNAL", then either `bad-host-backend` or `bad-host-host`
    must be set (not to "").

    You can set this when `lb-scheme` is "" but it will not have any impact
    in that case.  Other than that, if you set this when it cannot work, then
    the `plan` will include a parameter value that contains "ERROR" and
    mentions this setting and the `apply` will fail in a way that mentions
    the same.
  EOD
  type          = bool
  default       = false
}

variable "bad-host-code" {
  description   = <<-EOD
    When `lb-scheme` is left as "EXTERNAL_MANAGED" (and `url-map-ref` is ""),
    then the created URL Map will respond with this failure HTTP status code
    when a request is received for an unlisted hostname.  Set to 0 to have
    the URL Map ignore the request's hostname.

    Example: bad-host-code = 404
  EOD
  type          = number
  default       = 403

  validation {
    condition       = ( 0 == var.bad-host-code
        || 400 <= var.bad-host-code && var.bad-host-code < 600 )
    error_message   = "Must be 0 or 400..599."
  }
}

variable "bad-host-backend" {
  description   = <<-EOD
    When `url-map-ref` is "", the created URL Map can forward requests
    for unlisted hostnames to a different Backend Service (perhaps one
    that just rejects all requests).  For this to happen, you must set
    `bad-host-backend` to the `.id` of this alternate Backend Service.

    Example: bad-host-backend = google_compute_backend_service.reject.id
  EOD
  type          = string
  default       = ""
}

variable "bad-host-host" {
  description   = <<-EOD
    When `lb-scheme` is "EXTERNAL" (and `url-map-ref` and `bad-host-backend`
    are both ""), then the created URL Map can respond with a useless
    redirect when a request is received for an unlisted hostname ("EXTERNAL"
    URL Maps cannot directly reject requests).  Only if you set
    `bad-host-host` (not to "") will the URL Map do such redirects
    which will be to "https://$${bad-host-host}$${bad-host-path}".

    Example: bad-host-host = "localhost"
  EOD
  type          = string
  default       = ""
}

variable "bad-host-path" {
  description   = <<-EOD
    When `lb-scheme` is "EXTERNAL" and `bad-host-host` is not "", then
    the created URL Map will respond with a useless redirect to
    "https://$${bad-host-host}$${bad-host-path}" when a request is received
    for an unlisted hostname.  `bad-host-path` must start with "/".

    Example: bad-host-path = "/pound-sand"
  EOD
  type          = string
  default       = "/unknown-host"

  validation {
    condition       = "/" == substr( var.bad-host-path, 0, 1 )
    error_message   = "Must start with \"/\"."
  }
}

variable "bad-host-redir" {
  description   = <<-EOD
    When `lb-scheme` is "EXTERNAL" and `bad-host-host` is not "", then the
    created URL Map will respond with a useless redirect when a request is
    received for an unlisted hostname.  This sets the HTTP status code for
    that redirect and can be 301, 302, 303, 307, or 308.

    Example: bad-host-redir = 303
  EOD
  type          = number
  default       = 307

  validation {
    condition       = ( 301 <= var.bad-host-redir && var.bad-host-redir <= 303
      || 307 == var.bad-host-redir || 308 == var.bad-host-redir )
    error_message   = "Must be 301, 302, 303, 307, or 308."
  }
}

