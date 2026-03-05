# ==============================================================================
# Railway Brand Stack — Provider Configuration
#
# Authentication: set RAILWAY_TOKEN env var or pass via -var="railway_token=..."
# Each brand workspace has its own API token.
# ==============================================================================

provider "railway" {
  token = var.railway_token
}
