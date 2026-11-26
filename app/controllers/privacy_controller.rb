require 'uri'

class PrivacyController < ApplicationController
  def show
    email = ENV['PRIVACY_CONTACT_EMAIL'].to_s.strip
    @contact_email = email if email.match?(URI::MailTo::EMAIL_REGEXP)
  end
end
