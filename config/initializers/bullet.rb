# Configure Bullet gem for N+1 query detection
# See: https://github.com/flyerhzm/bullet

if Rails.env.development? || Rails.env.test?
  require 'bullet'
  
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
  Bullet.add_footer = true
  Bullet.raise = true if Rails.env.test?
end

