# Usage


## Contents

* [Option Toggles](#option-toggles)
* [Certificate Types](#certificate-types)
* [Hostnames](#hostnames)
* [Major Options](#major-options)


## Option Toggles

To open the documentation on "usage", here is a quick summary of the input
variables that toggle optional behaviors.  It may be best to first continue
to the next sections of this Usage documentation before jumping to read more
about one of these options; the first 3 are also covered under [Hostnames](
#hostnames) and several are covered in more detail under [Major Options](
#major-options).  But you can see [Inputs](/README.md#input-variables) for
links to more detailed documentation on each one.

* `dns-add-hosts` - Causes a DNS `A` record to be created for each "short"
    entry in `hostanames`.

* `create-lb-certs` - Creates "classic" LB-authorized SSL certificates for
    entries in `hostnames` (see [Classic Certificates](
    /docs/Created.md#classic-ssl-certificates)).

* `map-name` - Creates "modern" SSL certificates for entries in `hostnames`
    and a certificate map (see [Modern Certificates](
    /docs/Created.md#modern-ssl-certificates)).

* `redirect-http` - Can prevent the redirecting of http:// requests to
    become https:// requests (see [Redirect URL Map](
    /docs/Created.md#redirect-url-map)).

* `reject-honeypot` - Prevents requests for the "honeypot" hostname from
    being sent to your main Backend Service (see [Main URL Map](
    /docs/Created.md#main-url-map)).

* Several input variables whose names end in "-ref", when set (not to ""),
    will prevent the creation of a resource: `ip-addr-ref`, `cert-map-ref`,
    and `url-map-ref`.  This allows you full control over how such items are
    constructed.

* Specifying `dns-zone-ref` is required for a lot of the optional features.

* `lb-scheme`, `ip-addr-ref`, and `ip-is-shared` can prevent the creation
    of most of the load balancing infrastructure.

* If you set `lb-scheme = "EXTERNAL"` because you are not ready to use
    "modern" external HTTP/S load balancers, then the created URL Map
    cannot directly reject requests for unlisted hostnames, so you may
    want to also set either `bad-host-backend` or `bad-host-host`.  See
    [Main URL Map](/docs/Created.md#main-url-map) for details.

### Generic Options

The following input variables customize simple aspects of most of the created
infrastructure:  `name-prefix`, `project`, `description`, and 'labels'.


## Certificate Types

Before Cloud Certificate Manager, SSL certificates were just another part
of the load balancing (LB) infrastructure.  These "classic" certificates
can be GCP-Managed (auto renewing) if they are LB-authorized (created in
Terraform via `google_compute_managed_ssl_certificate` resource blocks).
You can also have "classic" certificates that are customer-managed (created
via `google_compute_ssl_certificate` resource blocks).

These "classic" certificates are used unless you use a certificate map
(either by setting `map-name` or `cert-map-ref`).  Using these cert types is
perhaps conceptually simpler but also can be more difficult to trouble-shoot,
easier to mess up in a way that causes an outage, won't support auto-renewed
wildcard certs, and lacks some security and other minor advantages.
You also can not do a disruption-free migration to a new ingress that uses
LB-authorized certificates.

Cloud Certificate Manager added the ability to create DNS-authorized
certificates (auto renewing and supporting wildcard certs) which you utilize
by creating a certificate map.  These "modern" certificates can also be
LB-authorized or customer-managed.  All 3 types of modern SSL certificates
are created using `google_certificate_manager_certificate` resource blocks.

These "modern" certificates are used if you set `map-name` or `cert-map-ref`.
"Modern" LB-authorized certs are very similar to the "classic" versions,
including being conceptually simpler.  DNS-authorized certs have some
advantages, though you may not find them worthwhile unless you are using
hostnames in a GCP-Managed DNS Zone that can be updated from the same
Terraform workspace (so that this module can make creation of them just as
simple), if you need a wildcard cert, or if you need to do a disruption-free
migration to your new ingress.

Hence the 3 documented examples.  The [Best Example](/README.md#best-example)
uses DNS-authorized certs for maximum benefit if you can manage the DNS Zone.
If not, you can use the [2nd-Best Example](/README.md#2nd-best-example) by
appending "|LB" to fully qualified hostnames.  Finally, start with the
[Simplest Example](/README.md#simplest-example) if you don't want the added
benefits of a certificate map (for whatever reason).


## Hostnames

Perhaps the most complicated input variable of this module is the list of
`hostnames`.  It can be referenced when creating each of these types of
resources:  DNS `A` records, a URL Map, 2 types of LB-authorized certificates,
DNS-authorized certificates (and the DNS Authorizations and DNS challenge
records they require), a URL Map, and a certificate map (the entries in it).
But you also can control which of those uses are done.

Each hostname can be in one of 3 formats:

* A (non-blank) name containing no "." characters
* A name ending in a "." character
* A fully qualified hostname (neither of the above)

The first component of a hostname can be "`*`", but only if using Cloud
Certificate Manager.

And each hostname can have one of the following suffixes appended to it:

* No suffix
* Just the character "|"
* The literal string "|LB"
* A "|" character followed by a 0-based index into `map-cert-ids`.

### Creating DNS `A` Records

Hostnames that contain no "." characters and hostnames that end in a "."
character require `dns-zone-ref` to point to a GCP-Managed DNS Zone.
They will have the zone domain appended to them.  These are also the
only hostnames that the module may create DNS `A` records for (only
when you set `dns-add-hosts = true`).  DNS `A` records are not created
for hostnames that start with "`*`" (nor for a blank hostname).

### Creating Certificates

There are 4 choices for how certificates may be created for entries in
`hostnames`:

* If `cert-map-ref` is set (not to ""), then it will refer to a certificate
    map you created outside of this module and so no certificates will be
    created for the entries in `hostnames`.

* Otherwise, if `map-name` is set (not to ""), then "modern" certificates
    will be created for (potentially) each entry in `hostnames`.

The default is to create a DNS-authorized certificate for each hostname
using Cloud Certificate Manager.  Appending just "|" to a hostname prevents
creation of the cert for that hostname (which also omits that hostname from
the certificate map).  Appending just "|LB" instead creates a "modern"
LB-authorized cert.  Appending "|" plus a numeric offset means to instead use
an `.id` from `map-cert-ids` for a certificate that was created elsewhere.
See [Modern Certificates](/docs/Created.md#modern-ssl-certificates) for
more details.

The `hostnames` will also be used to create a certificate map.  The first
hostname (that doesn't end in just "|") will be the PRIMARY entry -- the
"honeypot" cert that is handed out when an unknown hostname is used.  See
[Certificate Map](/docs/Created.md#certificate-map) for more details.

* Otherwise, if `create-lb-certs` is set to `true`, then a "classic" cert
    will be created for (potentially) each entry in `hostnames`.

The default is to create a "classic" LB-authorized certificate for each
hostname.  Appending just "|" to a hostname prevents creation of a cert for
that hostname (which usually means that you created the cert elsewhere and
reference it in `lb-cert-refs`).  Appending just "|LB" is the same as having
no suffix.  Appending "|" plus an index is not supported.  See [Classic
Certificates](/docs/Created.md#classic-ssl-certificates) for more details.

* Otherwise, no certificates are created and you would need to reference
    at least one "classic" certificate created elsewhere in `lb-cert-refs`
    or else no HTTPS load balancing will be configured (just HTTP).

### Creating A URL Map

If `url-map-ref` is not "" (and either `ip-addr-ref` is left blank or
`ip-is-shared` is set to `false`), then a simple URL Map is created.  By
default, that URL Map will not forward to your Backend any requests that
use an unlisted hostname.  See [Main URL Map](/docs/Created.md#main-url-map)
for details about how you can customize the created URL Map and setting
combinations that will cause requests from unlisted hostnames to be sent
to your Backend.


## Major Options

There are few input variables that select between different options that
have an impact on more than one item of infrastructure.

If `map-name` is set (not to ""), then a cert map will be created and so you
must not set `cert-map-ref`, `create-lb-certs`, nor `lb-cert-refs`.

If `cert-map-ref` is set (not to ""), then a cert map from elsewhere will be
used so you must not set `map-name`, `create-lb-certs`, nor `lb-cert-refs`.

You can use both `create-lb-certs` and `lb-cert-refs` at the same time,
but using either means you must not set `map-name` nor `cert-map-ref`.

You can set `lb-scheme` to "EXTERNAL", "EXTERNAL_MANAGED", or "".  This
(trivially) impacts the Global Forwarding Rules and has a larger impact
on the URL Map (see [Main URL Map](/docs/Created.md#main-url-map) for more
details).  If it is set to "", then none of these resources are created
(and neither are the Target Proxies), though this is usually only done
temporarily.

Several features require you to set `dns-zone-ref` (not to ""):  The creation
of DNS `A` records, the creation of DNS-authorized certificates, and the use
of short host names.  Leaving `dns-zone-ref` as "" just disables all of these
features:  Setting `add-dns-hosts = true` will fail; DNS-authorized cert
creations will fail; and the use of short hostnames will cause the creation
of any infrastructure based on such to fail.

Setting `ip-addr-ref` (not to "") will prevent the creation of much of
the load balancing infrastructure (target proxies, forwarding rules, and
a URL map) unless you also set `ip-is-shared = false`.  It prevents the
allocation of an IP address (even if you set `ip-is-shared = false`).

