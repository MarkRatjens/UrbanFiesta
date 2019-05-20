require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/activerecord'
require 'twilio-ruby'
require 'pony'

class UrbanFiesta < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  set :root, File.dirname(__FILE__)

  get '/credit_registrations/situation' do
    situations
    erb :"/credit_registrations/situation"
  end

  get '/credit_registrations/new/:situation' do
    erb :"/credit_registrations/new"
  end

  post '/credit_registrations/:situation' do
    resource.situation = params[:situation]
    resource.email = params[:email]
    resource.phone = params[:phone]
    resource.save
    redirect "/credit_registration/#{resource.id}/verification/#{verification.service_sid}"
  end

  get '/credit_registration/:id/verification/:service_sid' do
    @service_sid = params[:service_sid]
    resource(params[:id])
    erb :"/credit_registrations/accept_code"
  end

  post '/credit_registration/:id/verification_check/:service_sid' do
    @code = params[:code]
    @service_sid = params[:service_sid]
    resource(params[:id])
    resource.is_checked = verification_check.valid
    resource.save
    email
    erb :"/credit_registrations/show"
  end

  get '/credit_registration/:id' do
    resource(params[:id])
    erb :"/credit_registrations/show"
  end

  post '/credit_registration/:id/email' do
    'email credit registration results'
  end

  def situations
    @situations ||= {
      studentus: 'a student from the U.S.',
      studentabroad: 'a student from abroad',
      professional: 'a working professional',
      building: 'building my credit'
    }
  end

  def resource(id = nil)
    @r ||= id ? CreditRegistration.find(id) : CreditRegistration.new
  end

  def email
    Pony.options = {
      :subject => "Thanks for registering with Nyasa",
      :html_body => "<h1>You're on the waitlist!</h1>",
      :body => "You're on the waitlist",
      :via => :smtp,
      :via_options => {
        :address              => ENV['SMTP_ADDRESS'],
        :port                 => '587',
        :enable_starttls_auto => true,
        :user_name            => ENV['SMTP_FROM_ADDRESS'],
        :password             => ENV['SMTP_PASSWORD'],
        :authentication       => :plain, # :plain, :login, :cram_md5, no auth by default
        :domain               => ENV['EMAIL_DOMAIN']
      }
    }
    # Pony.mail(:to => resource.email)
  end

  def verification
    @verification ||= client.verify
      .services(service.sid)
      .verifications
      .create(to: resource.phone, channel: 'sms')
  end

  def verification_check
    @verification_check ||= client.verify
      .services(@service_sid)
      .verification_checks
      .create(to: resource.phone, code: @code)
  end

  def service
    @service ||= client.verify
      .services
      .create(friendly_name: 'Nyasa')
  end

  def client
    @client ||= Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
  end
end

class CreditRegistration < ActiveRecord::Base
end
