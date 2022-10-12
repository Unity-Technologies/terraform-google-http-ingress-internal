
output "keys" {
  description = "The hostnames minus '|..' suffixes; keys to below maps"
  value       = local.keys
}

output "dns" {
  description = "A map from hostname to DNS `A` Record resources created"
  value       = google_dns_record_set.d
}

output "ip" {
  description = "A 0- or 1-entry list of IP Address resource created"
  value       = google_compute_global_address.i
}

output "f80" {
  description = (
    "A 0- or 1-entry list of port-80 Forwarding Rule resource created" )
  value       = google_compute_global_forwarding_rule.f80
}

output "f443" {
  description = (
    "A 0- or 1-entry list of port-443 Forwarding Rule resource created" )
  value       = google_compute_global_forwarding_rule.f443
}

output "http" {
  description = (
    "A 0- or 1-entry list of Target HTTP Proxy resource created" )
  value       = google_compute_target_http_proxy.http
}

output "https" {
  description = (
    "A 0- or 1-entry list of Target HTTPS Proxy resource created" )
  value       = google_compute_target_https_proxy.https
}

output "lb-certs" {
  description = "A map from hostname to 'Classic' cert resources created"
  value       = google_compute_managed_ssl_certificate.c
}

output "cert-map" {
  description = "A 0- or 1-entry list of cert-map-simple module record"
  value       = module.cert-map
}

output "cert-map-id" {
  description = "A 0- or 1-entry list of certificate map ID"
  value       = local.cert-map-id
}

output "url-map" {
  description = "A 0- or 1-entry list of URL Map resource created"
  value       = google_compute_url_map.u
}

output "redir-map" {
  description = (
    "A 0- or 1-entry list of resource for URL Map to redirect to HTTPS" )
  value       = google_compute_url_map.redir
}

