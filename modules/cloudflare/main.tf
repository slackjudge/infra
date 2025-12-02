# DNS Record - Root domain (for Worker Route)
resource "cloudflare_dns_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  content = "192.0.2.1" # Dummy IP (Worker handles routing)
  type    = "A"
  proxied = true
  ttl     = 1
}

# DNS Record - www subdomain
resource "cloudflare_dns_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  content = var.domain_name
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

# Cloudflare Worker Script
resource "cloudflare_workers_script" "router" {
  account_id  = var.cloudflare_account_id
  script_name = "${var.project_name}-router"
  content     = <<-EOF
    export default {
      async fetch(request) {
        const url = new URL(request.url);

        // /api/* requests go to Backend (ALB)
        if (url.pathname.startsWith('/api')) {
          const backendUrl = '${var.backend_url}' + url.pathname + url.search;
          const response = await fetch(backendUrl, {
            method: request.method,
            headers: request.headers,
            body: request.body
          });

          // Disable cache for API responses
          const newResponse = new Response(response.body, response);
          newResponse.headers.set('Cache-Control', 'no-store, no-cache, must-revalidate');
          return newResponse;
        }

        // Other requests go to Frontend (S3)
        let path = url.pathname;
        if (path === '/' || !path.includes('.')) {
          path = '/index.html'; // SPA routing support
        }

        const frontendUrl = '${var.frontend_url}' + path;
        let response = await fetch(frontendUrl);

        // Return index.html for 404 (SPA routing)
        if (response.status === 404) {
          response = await fetch('${var.frontend_url}/index.html');
        }

        // Disable cache
        const newResponse = new Response(response.body, response);
        newResponse.headers.set('Cache-Control', 'no-store, no-cache, must-revalidate');
        return newResponse;
      }
    }
  EOF
}

# Worker Route - Connect Worker to domain
resource "cloudflare_workers_route" "main" {
  zone_id = var.cloudflare_zone_id
  pattern = "${var.domain_name}/*"
  script  = cloudflare_workers_script.router.script_name
}

resource "cloudflare_workers_route" "www" {
  zone_id = var.cloudflare_zone_id
  pattern = "www.${var.domain_name}/*"
  script  = cloudflare_workers_script.router.script_name
}

# Redirect Rules - Using cloudflare_ruleset (replaces deprecated page_rule)
resource "cloudflare_ruleset" "redirects" {
  zone_id     = var.cloudflare_zone_id
  name        = "${var.project_name}-redirects"
  description = "Redirect rules for ${var.domain_name}"
  kind        = "zone"
  phase       = "http_request_dynamic_redirect"

  rules = [
    {
      ref         = "www_to_root"
      description = "Redirect www to root domain"
      expression  = "(http.host eq \"www.${var.domain_name}\")"
      action      = "redirect"
      action_parameters = {
        from_value = {
          status_code = 301
          target_url = {
            expression = "concat(\"https://${var.domain_name}\", http.request.uri.path)"
          }
          preserve_query_string = true
        }
      }
      enabled = true
    }
  ]
}

# Zone Settings - Force HTTPS
resource "cloudflare_zone_setting" "always_use_https" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "always_use_https"
  value      = "on"
}

# Zone Settings - SSL Mode
resource "cloudflare_zone_setting" "ssl" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "ssl"
  value      = "flexible"
}
