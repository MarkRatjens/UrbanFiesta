class CreditRegistration < ActiveRecord::Base
  validates :phone, presence: true
  validates :email, presence: true

  def self.primer
    51723
  end

  def self.primer_count
    count + primer
  end

  def phoneWithCountryCode
    country_code + phone
  end

  def waitlist_position
    id + self.class.primer
  end

  def referral_code
    "#{email.upcase.delete('AEIOU._@')[0..4]}#{self.class.count + 1}".delete('0')
  end
end
