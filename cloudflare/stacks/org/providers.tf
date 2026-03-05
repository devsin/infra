# Auth: set CLOUDFLARE_API_TOKEN env var or pass cloudflare_api_token variable.
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
