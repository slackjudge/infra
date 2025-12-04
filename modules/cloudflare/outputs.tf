output "site_url" {
  description = "Frontend URL (HTTPS)"
  value       = "https://${var.domain_name}"
}

output "api_url" {
  description = "API URL (HTTPS)"
  value       = "https://api.${var.domain_name}"
}

output "worker_name" {
  description = "Cloudflare Worker name"
  value       = cloudflare_workers_script.router.script_name
}
