# frozen_string_literal: true

# Configure Rails Active Record Encryption
# Keys are stored in config/credentials.yml.enc under active_record_encryption
# Try to load from credentials first, fallback to direct configuration
begin
  encryption_config = Rails.application.credentials.dig(:active_record_encryption)
  if encryption_config && encryption_config[:primary_key].present?
    Rails.application.config.active_record.encryption.primary_key = encryption_config[:primary_key]
    Rails.application.config.active_record.encryption.deterministic_key = encryption_config[:deterministic_key]
    Rails.application.config.active_record.encryption.key_derivation_salt = encryption_config[:key_derivation_salt]
  else
    # Fallback: Set keys directly (for development - move to credentials for production)
    Rails.application.config.active_record.encryption.primary_key = "GrzaFdtW9RD556l3ayd3eVJKkrp4VGSF"
    Rails.application.config.active_record.encryption.deterministic_key = "ultYLS2EVSxhSoRHrSI9MKuOuacPvtnx"
    Rails.application.config.active_record.encryption.key_derivation_salt = "fqFMCR6FUSH3gB00FILLLq1tnh4iFCL9"
  end
rescue => e
  # If credentials can't be loaded, use fallback keys
  Rails.logger.warn "Could not load encryption keys from credentials: #{e.message}. Using fallback keys."
  Rails.application.config.active_record.encryption.primary_key = "GrzaFdtW9RD556l3ayd3eVJKkrp4VGSF"
  Rails.application.config.active_record.encryption.deterministic_key = "ultYLS2EVSxhSoRHrSI9MKuOuacPvtnx"
  Rails.application.config.active_record.encryption.key_derivation_salt = "fqFMCR6FUSH3gB00FILLLq1tnh4iFCL9"
end

# Validate encryption keys are present
unless Rails.application.config.active_record.encryption.primary_key.present?
  raise "Active Record Encryption primary_key must be configured"
end
