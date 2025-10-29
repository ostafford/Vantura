# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https, :unsafe_inline
    policy.style_src   :self, :https, :unsafe_inline
    policy.worker_src  :self
    policy.manifest_src :self

    # Allow connections to Up Bank API
    policy.connect_src :self, :https, "https://api.up.com.au"

    # Allow Vite dev server in development for HMR and asset loading
    if Rails.env.development?
      policy.connect_src :self, :https, "http://localhost:3036", "ws://localhost:3036"
    end

    # Specify URI for violation reports (optional - uncomment if you want CSP violation reports)
    # policy.report_uri "/csp-violation-report-endpoint"
  end

  # Generate session nonces for permitted Vite, inline scripts, and inline styles.
  # config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  # config.content_security_policy_nonce_directives = %w[script-src style-src]

  # Report violations without enforcing the policy (for testing).
  # Uncomment to test CSP without breaking functionality, then comment out once verified.
  # config.content_security_policy_report_only = true
end
