# DNS Record - Root domain (for Worker Route)
resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  value   = "192.0.2.1" # Dummy IP (Worker handles routing)
  type    = "A"
  proxied = true
}

# DNS Record - www subdomain
resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  value   = var.domain_name
  type    = "CNAME"
  proxied = true
}

# Cloudflare Worker Script
resource "cloudflare_worker_script" "router" {
  account_id = var.cloudflare_account_id
  name       = "${var.project_name}-router"
  content    = <<-EOF
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
resource "cloudflare_worker_route" "main" {
  zone_id     = var.cloudflare_zone_id
  pattern     = "${var.domain_name}/*"
  script_name = cloudflare_worker_script.router.name
}

resource "cloudflare_worker_route" "www" {
  zone_id     = var.cloudflare_zone_id
  pattern     = "www.${var.domain_name}/*"
  script_name = cloudflare_worker_script.router.name
}

# Page Rule - HTTP to HTTPS redirect
resource "cloudflare_page_rule" "https_redirect" {
  zone_id  = var.cloudflare_zone_id
  target   = "http://*${var.domain_name}/*"
  priority = 1

  actions {
    always_use_https = true
  }
}

# Page Rule - www to non-www redirect
resource "cloudflare_page_rule" "www_redirect" {
  zone_id  = var.cloudflare_zone_id
  target   = "www.${var.domain_name}/*"
  priority = 2

  actions {
    forwarding_url {
      url         = "https://${var.domain_name}/$1"
      status_code = 301
    }
  }
}
