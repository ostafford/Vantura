# frozen_string_literal: true

# Configure Rails Active Record Encryption
# Keys must be stored in config/credentials.yml.enc under active_record_encryption
# To edit credentials: bin/rails credentials:edit
# Reference: https://guides.rubyonrails.org/security.html#custom-credentials

encryption_config = Rails.application.credentials.dig(:active_record_encryption)

unless encryption_config && encryption_config[:primary_key].present?
  if Rails.env.test? || Rails.env.development?
    # In test/development environments, use deterministic keys if not configured
    # This allows tests and development to run without requiring credentials setup
    Rails.logger.warn "Active Record Encryption: Using fallback keys for #{Rails.env}. Configure credentials for production."
    Rails.application.config.active_record.encryption.primary_key = "0" * 64 # 32 bytes as hex
    Rails.application.config.active_record.encryption.deterministic_key = "1" * 64
    Rails.application.config.active_record.encryption.key_derivation_salt = "2" * 64
  else
    raise <<~ERROR
      Active Record Encryption keys must be configured in Rails credentials.

      To set up encryption keys:
      1. Run: bin/rails credentials:edit
      2. Add the following structure:

         active_record_encryption:
           primary_key: <32-byte hex string>
           deterministic_key: <32-byte hex string>
           key_derivation_salt: <32-byte hex string>

      3. Generate keys using: openssl rand -hex 32
    ERROR
  end
else
  Rails.application.config.active_record.encryption.primary_key = encryption_config[:primary_key]
  Rails.application.config.active_record.encryption.deterministic_key = encryption_config[:deterministic_key]
  Rails.application.config.active_record.encryption.key_derivation_salt = encryption_config[:key_derivation_salt]
end
