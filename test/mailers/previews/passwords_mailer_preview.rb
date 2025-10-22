# Preview all emails at http://localhost:3000/rails/mailers/passwords_mailer
class PasswordsMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/passwords_mailer/reset
  def reset
    user = User.first || User.new(
      email_address: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    PasswordsMailer.reset(user)
  end
end
