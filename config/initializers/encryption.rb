# frozen_string_literal: true

# Validate encryption key in production
if Rails.env.production?
  key = ENV.fetch("ENCRYPTION_KEY") do
    raise "ENCRYPTION_KEY environment variable must be set"
  end

  if key.bytesize < 32
    raise "ENCRYPTION_KEY must be at least 32 bytes (256 bits) for AES-256-GCM"
  end
end
