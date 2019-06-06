require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/activerecord'
require 'twilio-ruby'
require 'sendgrid-ruby'
require 'json'
require 'i18n'
require 'i18n/backend/fallbacks'
require 'clipboard'
require './credit_registration/models/credit_registration'

include SendGrid

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
    resource.referee_code = params[:code]
    erb :"/credit_registrations/new"
  end

  post '/credit_registrations/:situation' do
    resource.situation = params[:situation]
    resource.email = params[:email]
    resource.phone = params[:phone].gsub('-', '').gsub(' ', '')
    resource.country_code = params[:country_code]
    resource.referee_code = params[:referee_code]

    begin
      v = verification
      resource.referrer_code = resource.referral_code
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
    @code = params[:code][0 .. 5]
    @service_sid = params[:service_sid]
    resource(params[:id])
    resource.phone_is_checked = verification_check.valid
    resource.save
    send_email_confirmation if resource.phone_is_checked
    erb :"/credit_registrations/confirm_email_address"
  end

  get '/credit_registration/:id/email_check/:email' do
    resource(params[:id])
    resource.email_is_checked = (resource.email == params[:email])
    resource.save
    email_success ifresource.phone_is_checked
    erb :"/credit_registrations/show"
  end

  get '/credit_registration/:id/copy_code' do
    resource(params[:id])
    Clipboard.copy("#{request.host}:#{request.port}/credit_registrations/situation/#{resource.referrer_code}")
    redirect "/credit_registration/#{resource.id}/email/#{resource.email}"
  end

  get '/credit_registration/:id/email/:email' do
    resource(params[:id])
    erb :"/credit_registrations/show" if resource.email == params[:email]
  end

  #  get '/credit_registration/:id/invalid' do
  #    resource(params[:id])
  #    erb :"/credit_registrations/show_invalid"
  #  end

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

  #
  # take this out!
  # ||||||||||||||
  # ||||||||||||||
  # vvvvvvvvvvvvvv
  get '/credit_registration/:id' do
    resource(params[:id])
    send_email_confirmation
    send_success_email
  end

  def send_email_confirmation
    r = email_client.client.mail._('send').post(request_body: confirmation_email.to_json)
    puts '-' * 111
    puts r.status_code
    puts r.body
    puts r.headers
    puts '=' * 111
  end

  def send_success_email
    r = email_client.client.mail._('send').post(request_body: success_email.to_json)
    puts '-' * 111
    puts r.status_code
    puts r.body
    puts r.headers
    puts '=' * 111
  end

  def confirmation_email
    m ||= SendGrid::Mail.new
    m.template_id = ENV['CONFIRMATION_TEMPLATE_ID']
    m.from = from_address
    m.subject = I18n.t('confirm_email_address_email.subject')
    m.add_personalization(confirmation_personalization)
    m
  end

  def confirmation_personalization
    p ||= Personalization.new
    p.add_to(to_address)
    p.add_dynamic_template_data({
      variable: [
        { page_title: I18n.t('page_title.email_address_confirmation') },
        { first: I18n.t('confirm_email_address_email.first') },
        { url: "#{request.host}/credit_registration/#{resource.id}/email_check/#{resource.email}" },
        { button_text: I18n.t('confirm_email_address_email.button') }
      ]
    })
    p
  end

  def success_email
    m ||= SendGrid::Mail.new
    m.template_id = ENV['SUCCESS_TEMPLATE_ID']
    m.from = from_address
    m.subject = I18n.t('success_email.subject')
    m.add_personalization(success_personalization)
    m
  end

  def success_personalization
    p ||= Personalization.new
    p.add_to(to_address)
    p.add_dynamic_template_data({
      variable: [
        { page_title: I18n.t('page_title.success') },
        { waitlist_position: resource.waitlist_position },
        { waitlist_size: CreditRegistration.primer_count },
        { first: I18n.t('success_page.get_app.first.first') },
        { next: I18n.t('success_page.get_app.first.next') },
        { url: "#{request.host}/credit_registrations/situation/#{resource.referrer_code}" }
      ]
    })
    p
  end

  def from_address
    SendGrid::Email.new(email: ENV['FROM_ADDRESS'] || 'noreply@nyasa.io')
  end

  def to_address
    SendGrid::Email.new(email: resource.email)
  end

  def verification
    @verification ||= twilio_client.verify
      .services(service.sid)
      .verifications
      .create(to: "#{resource.country_code}#{resource.phone}", channel: 'sms')
  end

  def verification_check
    @verification_check ||= twilio_client.verify
      .services(@service_sid)
      .verification_checks
      .create(to: resource.phoneWithCountryCode, code: @code)
  end

  def service
    @service ||= twilio_client.verify
      .services
      .create(friendly_name: 'Nyasa')
  end

  def twilio_client
    @twilio_client ||= Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
  end

  def email_client
    @email_client ||= SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
                    # SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'], host: 'https://api.sendgrid.com')
  end
end
