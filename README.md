# terraform-google-https-ingress

A Terraform module for building HTTP/S load balancing ingresses with
similar features to GKE ingress automation (but better).


## Contents

* [Simplest Example](#simplest-example)
* [Features](#features)
* [Best Example](#best-example)
* [2nd-Best Example](#2nd-best-example)
* [Detailed Documentation](#detailed-documentation)
* [Input Variables](#input-variables)


## Simplest Example

First, let's see how simple this module can be to use.  This invocation
of the module configures global HTTP and HTTPS load balancing to your
Backend Service using a "Classic" load-balancer-authorized SSL certificate
(including allocating an IP address and creating a simple URL Map but not
setting up DNS for it).

    module "my-ingress" {
      source            = (
        "github.com/TyeMcQueen/terraform-google-https-ingress" )
      name-prefix       = "my-svc-"
      hostnames         = [ "my-svc.my-product.example.com" ]
      create-lb-certs   = true
      backend-ref       = google_compute_backend_service.my-svc.id
    }

You can get additional security and reliability benefits by using a
certificate map from Cloud Certificate Manager (see examples below).

You need to create a Backend Service (or a custom URL Map).  You may want
to use one of these related Terraform modules to do that:

* [backend-to-gke](
    https://github.com/TyeMcQueen/terraform-google-backend-to-gke) - Builds
    a Backend Service to route to NEGs created for a Kubernetes Workload
    deployed to 1 or more GKE clusters.
* [ingress-to-gke](
    https://github.com/TyeMcQueen/terraform-google-ingress-to-gke) - A
    wrapper that combines the backend-to-gke and http-ingress modules to
    make it very simple to build a full ingress to a GKE Workload (perhaps
    running in multiple regions).

The LB-authorized certificate will not become active until your hostname
is set up in DNS to point to the allocated IP address (plus about 20 minutes
to finish the automated authorization process).


## Features

This module makes it easy to allocate GCP Global L7 (HTTP/S) Load Balancing
to route to a GCP Backend Service or to a custom URL Map.

### Very Simple

This module makes common use cases very simple to achieve.

### More Complete

This module can set up everything needed for an ingress to your backend:
allocate the IP address, set up DNS records for your hostname(s), create
GCP-Managed SSL Certificates (3 different kinds), create a simple URL Map,
and tie all of the load-balancing pieces of infrastructure together.  Or you
can easily tell it to use specific parts that you manage outside of the
module for maximum flexibility.

### Can Use A Certificate Map

You can use GCP's new Cloud Certificate Manager to create a certificate
map which provides more reliability and security benefits and can auto-renew
even wildcard certs.  See the [certificate-map-simple module](
https://github.com/TyeMcQueen/terraform-google-certificate-map-simple) for
more about these benefits.

### More Flexibility

This module supports full control over nearly every aspect of the creation
of this infrastructure.  You can do more advanced configurations like:

* Share a URL Map and/or an IP Address between multiple Backends
* Choose between Classic and Modern L7 LB schemes
* Use any advanced URL Map features
* Migrate traffic with no interruption of service


## Best Example

This example provides the most benefits (including better reliability and
security and simpler troubleshooting) and is still very simple but requires
that your hostnames are part of a GCP-Managed DNS Zone that your Terraform
workspace has write access to.  It even creates the DNS records for your
hostnames.

    module "my-ingress" {
      source            = (
        "github.com/TyeMcQueen/terraform-google-http-ingress" )
      name-prefix       = "my-svc-"
      map-name          = "my-svc"
      hostnames         = [ "honeypot", "svc" ]
      reject-honeypot   = true
      dns-zone-ref      = "my-zone"
      dns-add-hosts     = true
      backend-ref       = google_compute_backend_service.my-svc.id
    }

By using a Cloud Certificate Manager certificate map you get additional
benefits including a "honeypot" hostname, a certificate for which will be
given to hackers that hit your load balancer IP address using HTTPS but
with some random hostname.  This prevents the hackers from trivially being
able to discover the hostname to use for further scanning/attack attempts.
And `reject-honeypot` means requests that use the honeypot hostname will
not even be routed to your Backend.

The [certificate-map-simple module](
github.com/TyeMcQueen/terraform-google-certificate-map-simple) that this
module uses fully documents these additional benefits.

### Avoiding Nested Modules

The above example is the same as the following example where the use of the
other module is made explicit.  This approach is recommended by Terraform
as a best practice for combining modules.  But you can start with the simpler
usage above and then move to this more verbose usage when the need arises.

    module "my-cert-map" {
      source            = (
        "github.com/TyeMcQueen/terraform-google-certificate-map-simple" )
      name-prefix       = "my-svc-"
      map-name1         = "my-svc"
      hostnames1        = [ "honeypot", "svc" ]
      dns-zone-ref      = "my-zone"
    }

    module "my-ingress" {
      source            = (
        "github.com/TyeMcQueen/terraform-google-http-ingress" )
      name-prefix       = "my-svc-"
      hostnames         = [ "honeypot", "svc" ]
      reject-honeypot   = true
      dns-zone-ref      = "my-zone"
      dns-add-hosts     = true
      backend-ref       = google_compute_backend_service.my-svc.id
      cert-map-ref      = module.my-cert-map[0].map-id1[0]
      # Above added in place of `map-name`
    }


## 2nd-Best Example

If your Terraform workspace can't manage the DNS Zone for your hostname(s),
then you can still get the "honeypot" benefit of using a certificate map
by using "modern" LB-authorized certificates (by appending "|LB" to each
hostname).

    module "my-ingress" {
      source            = (
        "github.com/TyeMcQueen/terraform-google-http-ingress" )
      name-prefix       = "my-svc-"
      map-name          = "my-svc"
      hostnames         = [
        "honeypot.my-product.example.com|LB",
        "my-svc.my-product.example.com|LB",
      ]
      reject-honeypot   = true
      backend-ref       = google_compute_backend_service.my-svc.id
    }

This way you lose some minor resiliency benefits of using DNS-authorized
certificates, but those may not be worth the added complexity of using
DNS-authorized certs when the authorization can't be automated.  Though, if
you want to migrate traffic to this new configuration without any disruption,
then you will need to use DNS-authorized certificates or temporarily use
customer-managed certificates.


## Detailed Documentation

This module is very flexible/powerful, supporting a lot of options that give
you full control over your infrastructure.  We encourage you to start with
one of the simple examples (above) and customize that as needed.  If you
try to look at all of the possible options, it is easy to be overwhelmed.

Most aspects of the module are documented from multiple angles.  When
you are ready to customize, you should probably start with the [Usage](
/docs/Usage.md) documentation.  Depending on what angle you want to look
from, you can also look at any of these lists:

* [What infrastructure can be created](/docs/Created.md)
* Input [variables.tf](/variables.tf) or the [sorted list of links](
    #input-variables) to the documentation for each input.
* [Known limitations](/docs/Limitations.md)

The [Usage](/docs/Usage.md) documentation includes the following sections:

* [Option Toggles](/docs/Usage.md#option-toggles)
* [Certificate Types](/docs/Usage.md#certificate-types)
* [Hostnames](/docs/Usage.md#hostnames)
* [Major Options](/docs/Usage.md#major-options)

[outputs.tf](/outputs.tf) simply lists all of the outputs from this module.

Limitations:

* [Google Providers](/docs/Limitations.md#google-providers)
* [Error Handling](/docs/Limitations.md#error-handling)
* [Unused Resource Types](/docs/Limitations.md#unused-resource-types)

You should also be aware of types of changes that require special care as
documented in the other module's limitations: [Deletions](
https://github.com/TyeMcQueen/terraform-google-ingress-to-gke/blob/main/Limitations.md#deletions).


## Input Variables

* [backend-ref](/variables.tf#L133)
* [bad-host-code](/variables.tf#L418)
* [bad-host-host](/variables.tf#L437)
* [bad-host-path](/variables.tf#L451)
* [bad-host-redir](/variables.tf#L469)
* [cert-map-ref](/variables.tf#L261)
* [create-lb-certs](/variables.tf#L65)
* [description](/variables.tf#L298)
* [dns-add-hosts](/variables.tf#L341)
* [dns-ttl-secs](/variables.tf#L350)
* [dns-zone-ref](/variables.tf#L174)
* [hostnames](/variables.tf#L18)
* [http-redir-code](/variables.tf#L395)
* [ip-addr-ref](/variables.tf#L208)
* [ip-is-shared](/variables.tf#L325)
* [labels](/variables.tf#L309)
* [lb-cert-refs](/variables.tf#L246)
* [lb-scheme](/variables.tf#L104)
* [map-cert-ids](/variables.tf#L228)
* [map-name](/variables.tf#L80)
* [name-prefix](/variables.tf#L5)
* [project](/variables.tf#L285)
* [quic-override](/variables.tf#L361)
* [redirect-http](/variables.tf#L383)
* [url-map-ref](/variables.tf#L152)
