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

# Cloudflare Worker Script (Service Worker format)
resource "cloudflare_workers_script" "router" {
  account_id  = var.cloudflare_account_id
  script_name = "${var.project_name}-router"
  content     = <<-EOF
addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request));
});

async function handleRequest(request) {
  const url = new URL(request.url);

  // www to non-www redirect
  if (url.hostname.startsWith('www.')) {
    const redirectUrl = 'https://${var.domain_name}' + url.pathname + url.search;
    return Response.redirect(redirectUrl, 301);
  }

  // Handle CORS preflight
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Max-Age': '86400'
      }
    });
  }

  // /api/* requests go to Backend (ALB)
  if (url.pathname.startsWith('/api')) {
    const backendUrl = '${var.backend_url}' + url.pathname + url.search;

    // Build new headers (exclude Host to let fetch set it correctly)
    const newHeaders = new Headers();
    for (const [key, value] of request.headers) {
      if (key.toLowerCase() !== 'host') {
        newHeaders.set(key, value);
      }
    }

    // Build fetch options (no body for GET/HEAD)
    const fetchOptions = {
      method: request.method,
      headers: newHeaders
    };

    if (!['GET', 'HEAD'].includes(request.method)) {
      fetchOptions.body = request.body;
    }

    const response = await fetch(backendUrl, fetchOptions);

    // Add CORS and cache headers
    const newResponse = new Response(response.body, response);
    newResponse.headers.set('Cache-Control', 'no-store, no-cache, must-revalidate');
    newResponse.headers.set('Access-Control-Allow-Origin', '*');
    newResponse.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    newResponse.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    return newResponse;
  }

  // Other requests go to Frontend (S3)
  let path = url.pathname;
  if (path === '/' || !path.includes('.')) {
    path = '/index.html';
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
