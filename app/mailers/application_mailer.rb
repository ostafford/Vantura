class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "okky.mstafford@gmail.com")
  layout "mailer"
end
