# Infrastructure Created

Here we document every item of infrastructure that can be provisioned
by using this module and under which conditions each will be created.
We also list which input variables can be used to customize each, what
prerequisites each requires, and what output value contains the resulting
resource record(s), but it is all organized here by what gets created.

If the customizations provided by input variables are insufficient for your
needs, then the module probably allows you to just create that infrastructure
yourself and hand it to the module via a variable whose name ends in "-ref".

The easiest way to jump to the documentation for a specific input variable
is to find the link to it in the sorted list of [inputs](
/README.md#input-variables).

If you invoke a module via

    module "NAME" {

then an output value from that invocation can be accessed via an expression
like `module.NAME.ip[0]`.  Below, output values will often be documented
using similar full expressions.  Sometimes, a shorter form like `.ip[0]` or
even `ip[0]` will be used.


## Contents

* [IP Address](#ip-address)
* [Classic SSL Certificates](#classic-ssl-certificates)
* [Modern SSL Certificates](#modern-ssl-certificates)
* [DNS `A` Record(s)](#dns-a-records)
* [Target Proxies, Forwarding Rules](#target-proxies-forwarding-rules)
* [Redirect URL Map](#redirect-url-map)
* [Main URL Map](#main-url-map)


## IP Address

Only when `ip-addr-ref` is left blank, the following is allocated:

* A GCP (Premium) Global IP Address

You would use `ip-addr-ref` if you already allocated an IP address that
you wanted to use instead of having the module allocate one.

The output value `.ip[0]` will contain the resource record if one was
created.  The only customization is via the general options (`project`,
`name-prefix`, `labels`, and `description`).  No prerequisites.


## Classic SSL Certificates

Only when you set `create-lb-certs = true` and `hostnames` is not left
empty, the following are created:

* A "Classic" GCP-Managed SSL Certificate for each entry in `hostnames`
    not marked for exclusion

An "|LB" suffix is allowed but makes no difference here.  Hostnames with
just a "|" character appended do not have certificates created for them.
Any other value after "|" is not supported (currently treated the same as
just "|").

These certificates do not use Cloud Certificate Manager and are authorized
by the load balancer, which means that the certificate will not be able to
be activated until a while after the load balancer instance is live and
the specified hostname (publicly) resolves to the LB IP address.  But the
`terraform apply` can succeed even if the cert will not be able to be
activated.  If the activation fails for long enough, then attempts to
activate will stop and the cert will have to be recreated to have activation
attempts resume.

The output value `.lb-certs` will be a map from the entered hostname
(minus "|..." suffix) to the resource object.  The only customization is
via the general options (`project`, `name-prefix`, and `description`).
No prerequisites for `terraform apply`.


## Modern SSL Certificates

Only when `map-name` is not left blank, the following are created:

* A "Modern" GCP-Managed SSL Certificate for each entry in `hostnames`
    not marked for exclusion
* Other items to authorize any DNS-authorized certs created above
* A Certificate Map with entries for (potentially) each hostname

The certificates use Cloud Certificate Manager and can be authorized via
the load balancer or via a DNS challenge.  Hostnames with just a "|"
character appended or with "|" followed by a numeric offset will not have
a certificate created.

### Certificate Map

A certificate map is created having the name given in `map-name`.  For each
hostname in `hostnames` (except those that end in just "|"), an entry is
added to the map.  The first hostname will be the "PRIMARY" and its
certificate will be handed out whenever a request uses a hostname not
matching any of the other map entries.

Prerequisites are `map-name` and `hostnames` and the certs created for or
referenced (via `map-cert-ids`) by entries in `hostnames`.  The only other
customization is via the general options (`project`, `name-prefix`, `labels`,
and `description`).  The output value `module.NAME.cert-map[0].map1[0]` will
be the resource record of the created map.  To use the certificate map, it
is better to use `module.NAME.cert-map[0].map-id1[0]`.

### Modern LB-Authorized Certificates

Each hostname that has "|LB" appended will have an LB-authorized cert
created and "modern" LB-authorized certs have the same prerequisites and
behaviors as described in [Classic Certs](#classic-ssl-certificates).

The only customization is via the general options (`project`,
`name-prefix`, `labels`, and `description`).  The output value
`module.NAME.cert-map[0].dns-certs` will be a map from _fully qualified_
hostnames to the resource records for the created LB-authorized certs.

### DNS-Authorized Certificates

Each hostname that has no "|" will have several things created to fully
provision a DNS-authorized cert.  This requires the Terraform workspace
to have write access to a GCP-Managed DNS Zone that is referenced via
`dns-zone-ref`.

First a DNS Authorization is created.  Then a DNS Record fulfilling that
authorization challenge will be added to the Zone.  Then a DNS-authorized
cert will be created.  The `terraform apply` will not wait for the cert
to become active but the only additional requirement for that to happen
is that the Zone be delegated to from the parent domain so DNS requests
via the internet reach the GCP-Managed Zone.

Prerequisites: `dns-zone-ref` and write access to the referenced DNS Zone,
`map-name`, and `hostnames`.  For certificate activation: public delegation
to the DNS Zone.

For DNS Records, the only customization is via `project` and only if
`dns-zone-ref` does not include a project ID.  The output value
`module.NAME.cert-map[0].dns-records` will be a map from _fully qualified_
hostnames to the resource record for the created DNS Record.

For DNS-Authorized Certificates and DNS Authorizations, the only
customization is via the general options (`project`, `name-prefix`, `labels`,
and `description`).  The output values `module.NAME.cert-map[0].dns-certs`
and `module.NAME.cert-map[0].dns-auths` will be maps from _fully qualified_
hostnames to the respective resource records.


## DNS `A` Record(s)

Only when you set `dns-add-hosts = true` and `hostnames` is not left empty,
the following are created:

* A DNS `A` Record for each "short" entry in `hostnames`

This requires that `dns-zone-ref` be a reference to a GCP-Managed DNS Zone
that Terraform can update.

For every entry in `hostnames` (ignoring any "|" suffix) that either contains
no "." characters or ends in a "." character, a DNS `A` Record will be
created for that hostname (with the Zone's domain appended) and resolving to
the IP Address (either created or referenced via `ip-addr-ref`).  Except that
no DNS records are created for hostnames that contain a "`*`" character nor
for blank hostnames.  The records are created in the project that owns the
Zone.

No customizations.


## Target Proxies, Forwarding Rules

Only when `lb-scheme` is not "" and either `ip-addr-ref` is left blank or
`ip-is-shared` is set to `false`, the following are created:

* An HTTP Target Proxy
* A Global Forwarding Rule for port 80

The following are also created if any of these input variables
are not left at their default values: `map-name`, `cert-map-ref`,
`create-lb-certs`, or `lb-cert-refs`.

* An HTTPS Target Proxy
* A Global Forwarding Rule for port 443

The prerequisites for the Forwarding Rules are the IP Address (either
referenced by `ip-addr-ref` or created because it is "") plus the Target
Proxies.  The prerequisite for the Target Proxies is the URL Map (either
referenced by `url-map-ref` or created because it is "").

Customization via the general options (`project`, `name-prefix`, and
`description`) applies to each of the above and `labels` applies only to
the Forwarding Rules.  The forwarding rules are trivially customized by
`lb-scheme`.

Only the HTTPS Target Proxy supports any other customization.  It is
customized by the simple option `quic_override`.  It is customized with each
certificate that was either created or referenced.  Certs can be created for
entries in `hostnames`.  Certs can be referenced via `lb-cert-refs` or
`map-cert-ids` (the latter requires a related entry in `hostnames`).  For
created certs, see [Classic Certs](#classic-ssl-certificates) or [Modern
Certs](#modern-ssl-certificates) (the latter can only be attached via a
created certificate map).

See [inputs](/README.md#input-variables) or [variables](/variables.tf) for
more details.  The output values `.http[0]`, `.https[0]`, `.f80[0]`, and
`.f443[0]` will be the resource records of the created resource.


## Redirect URL Map

Only when the HTTPS Target Proxy is created and `redirect-http` is `true`,
the following is created:

* One redirect URL Map

The redirect URL Map can be customized by the following input variables:
`http-redir-code`, `project`, `name-prefix`, and `description`.  The output
value `module.NAME.redir-map[0]` will contain the resource record if it is
created.


## Main URL Map

Only when `url-map-ref` is left blank and target proxies and forwarding rules
are created (that is, when `lb-scheme` is not "" and either `ip-addr-ref` is
left blank or `ip-is-shared` is set to `false`), the following is created:

* One simple URL Map

URL Maps support very complex configuration options so you can choose to
create your own URL Map (via `url-map-ref`) if the simple one created by
this module with its very limited customization options does not meet your
needs.  The value you use for `lb-scheme` will significantly impact which
features you can use in your URL Map.

The prerequisites for the created URL Map are `backend-ref` and non-empty
`hostnames` (unless you customize the URL Map to not care about `hostnames`).

The URL Map can be customized by the following input variables: `lb-scheme`,
`hostnames`, `bad-host-code`, `bad-host-host`, `bad-host-path`,
`bad-host-redir`, `project`, `name-prefix`, and `description`.  Only when
`lb-scheme` is "EXTERNAL" do `bad-host-host`, `bad-host-path`, and
`bad-host-redir` apply.  Only when `lb-scheme` is "EXTERNAL_MANAGED" does
`bad-host-code` apply.  See [inputs](/README.md#input-variables) or
[variables](/variables.tf) for more details.

By default, the URL Map will not route a request to your Backend unless
the request uses one of the listed `hostnames`.

If you leave `lb-scheme` as "EXTERNAL_MANAGED", then requests using other
hostnames will be rejected with a 403 status (unless you change
`bad-host-code`).  Setting `bad-host-code = 0` means all requests will
be routed to your Backend regardless of the hostname used in the request.

If you set `lb-scheme` to "EXTERNAL", then requests for unlisted hostnames
will get a useless 307 redirect to "https://localhost/bad-host" (by default)
since Classic L7 LBs do not support generating failure responses.  You can
change the 307 status via `bad-host-redir`.  You can replace the "/bad-host"
part of the redirect by setting `bad-host-path`.  Setting `bad-host-path = ""`
will cause the URL Map to route all requests to your Backend regardless of the
hostname used in the request.

The output value `.url-map[0]` will be the resource record if a URL Map is
created.

