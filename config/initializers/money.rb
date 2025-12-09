# config/initializers/money.rb
MoneyRails.configure do |config|
  # Set default currency
  config.default_currency = :aud

  # Explicitly set localization behavior to silence deprecation warning
  config.locale_backend = :i18n

  # Configure amount column (optional)
  config.no_cents_if_whole = false
end
