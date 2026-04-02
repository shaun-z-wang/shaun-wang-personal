# Quick cd shortcuts for common project directories
ccd() {
  case "$1" in
    rid) cd /home/bento/carrot/customers/customers-backend/domains/retailer_integrations_domain ;;
    fps) cd /home/bento/carrot/fulfillment/fulfillment_provider_service ;;
    *) echo "Usage: ccd <rid|fps>" ;;
  esac
}
