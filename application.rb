require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/activerecord'
require 'twilio-ruby'
require 'pony'
require 'i18n'
require 'i18n/backend/fallbacks'
require 'clipboard'
require './credit_registration/models/credit_registration'

class UrbanFiesta < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  configure do
    I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
    I18n.load_path = Dir[File.join(settings.root, 'locales', '*.yml')]
    I18n.backend.load_translations
  end

  set :root, File.dirname(__FILE__)

  get '/' do
    situations
    erb :"/credit_registrations/situation"
  end

  get '/credit_registrations/situation' do
    situations
    erb :"/credit_registrations/situation"
  end

  get '/credit_registrations/situation/:code' do
    situations
    erb :"/credit_registrations/situation"
  end

  get '/credit_registrations/new/:situation' do
    resource
    erb :"/credit_registrations/new"
  end

  get '/credit_registrations/new/:situation/:code' do
    resource
    erb :"/credit_registrations/new"
  end

  post '/credit_registrations/:situation' do
    resource.situation = params[:situation]
    resource.email = params[:email]
    resource.phone = params[:phone].gsub('-', '').gsub(' ', '')
    resource.country_code = params[:country_code]

    begin
      v = verification
      resource.referrer_code = resource.referral_code
      resource.referee_code = params[:referrer_code]
      resource.save
      redirect "/credit_registration/#{resource.id}/verification/#{v.service_sid}"
    rescue Twilio::REST::RestError => e
      @phone_invalid = true
      erb :"/credit_registrations/new"
    end
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

  get '/credit_registration/:id/email' do
    resource(params[:id])
    email
    erb :"/credit_registrations/show"
  end

#  get '/credit_registration/:id' do
#    resource(params[:id])
#    erb :"/credit_registrations/show"
#  end

#  get '/credit_registration/:id/invalid' do
#    resource(params[:id])
#    erb :"/credit_registrations/show_invalid"
#  end

  post '/credit_registration/:id/email' do
    'email credit registration results'
  end

  get '/credit_registration/:id/copy_code' do
    resource(params[:id])
    Clipboard.copy("#{request.env["HTTP_HOST"]}/credit_registrations/situation/#{resource.referrer_code}")
    redirect "/credit_registration/#{resource.id}"
  end

  def situations
    @situations ||= [
      :professional_foreign,
      :resident_us,
      :student_foreign,
      :student_us,
      :build_score
    ]
  end

  def resource(id = nil)
    @r ||= id ? CreditRegistration.find(id) : CreditRegistration.new
  end

  def email
    Pony.mail(email_options.merge(smtp_options))
  end

  def email_options
    @email_options ||=
      {
        to: resource.email,
        from: ENV['FROM_ADDRESS'] || 'noreply@nyasa.io',
        subject: 'Thanks for joining the Opal waitlist',
        html_body: (erb :"credit_registrations/show_success")
      }
  end

  def smtp_options
    @smtp_options ||= {
      via: :smtp,
      via_options:{
        address: ENV['SMTP_ADDRESS'],
        port: '587',
        enable_starttls_auto: true,
        user_name: ENV['SMTP_USER_NAME'] || 'roreply@nyasa.io',
        password: ENV['SMTP_PASSWORD'],
        authentication: :plain, # :plain, :login, :cram_md5, no auth by default
        domain: ENV['EMAIL_DOMAIN'] || 'nyasa.io'
      }
    }
  end

  def verification
    @verification ||= client.verify
      .services(service.sid)
      .verifications
      .create(to: "#{resource.country_code}#{resource.phone}", channel: 'sms')
  end

  def verification_check
    @verification_check ||= client.verify
      .services(@service_sid)
      .verification_checks
      .create(to: resource.phoneWithCountryCode, code: @code)
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
