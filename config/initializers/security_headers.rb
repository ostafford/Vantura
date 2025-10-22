# Security Headers Configuration
# Based on Rails Security Guide: https://guides.rubyonrails.org/security.html#default-security-headers
#
# These headers help protect against common web vulnerabilities:
# - X-Frame-Options: Prevents clickjacking attacks
# - X-Content-Type-Options: Prevents MIME-sniffing attacks
# - X-XSS-Protection: Disabled (0) as modern browsers use CSP instead
# - Referrer-Policy: Controls how much referrer information is sent

Rails.application.config.action_dispatch.default_headers.merge!(
  "X-Frame-Options" => "SAMEORIGIN",
  "X-Content-Type-Options" => "nosniff",
  "X-XSS-Protection" => "0",
  "Referrer-Policy" => "strict-origin-when-cross-origin"
)
