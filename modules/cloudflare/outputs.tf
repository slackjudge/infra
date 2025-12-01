output "site_url" {
  description = "Final service URL (HTTPS)"
  value       = "https://${var.domain_name}"
}

output "worker_name" {
  description = "Cloudflare Worker name"
  value       = cloudflare_worker_script.router.name
}
