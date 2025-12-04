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

# DNS Record - API subdomain (direct to ALB)
resource "cloudflare_dns_record" "api" {
  zone_id = var.cloudflare_zone_id
  name    = "api"
  content = var.backend_dns_name
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

# Cloudflare Worker Script - SPA routing only
resource "cloudflare_workers_script" "router" {
  account_id  = var.cloudflare_account_id
  script_name = "${var.project_name}-router"
  content     = <<-EOF
addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request));
});

async function handleRequest(request) {
  const url = new URL(request.url);

  // Determine path: serve index.html for non-file routes (SPA routing)
  let path = url.pathname;
  if (path === '/' || !path.includes('.')) {
    path = '/index.html';
  }

  const frontendUrl = '${var.frontend_url}' + path;
  let response = await fetch(frontendUrl);

  // SPA routing: return index.html for 404 (with 200 OK)
  if (response.status === 404) {
    response = await fetch('${var.frontend_url}/index.html');
  }

  return response;
}
  EOF
}

# Worker Route - Connect Worker to root domain only
resource "cloudflare_workers_route" "main" {
  zone_id = var.cloudflare_zone_id
  pattern = "${var.domain_name}/*"
  script  = cloudflare_workers_script.router.script_name
}

# Page Rule - www to non-www redirect (301)
resource "cloudflare_page_rule" "www_redirect" {
  zone_id  = var.cloudflare_zone_id
  target   = "www.${var.domain_name}/*"
  priority = 1
  actions {
    forwarding_url {
      url         = "https://${var.domain_name}/$1"
      status_code = 301
    }
  }
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
