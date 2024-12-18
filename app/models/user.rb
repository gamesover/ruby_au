class User < ApplicationRecord
  has_many :emails, dependent: :destroy # must be declared before devise :multi_email_authenticatable

  # Include devise modules. Others available are:
  # :lockable, :timeoutable, and :omniauthable
  devise :multi_email_authenticatable,
         :multi_email_confirmable,
         :multi_email_validatable,
         :registerable,
         :recoverable,
         :rememberable,
         :trackable

  has_many :memberships, dependent: :destroy

  scope :unconfirmed, -> { where(confirmed_at: nil) }
  scope :old, -> { where('created_at < ?', 2.weeks.ago) }
  scope :subscribed_to_any_list, lambda {
    where(
      MailingList::LISTS.collect do |list|
        "mailing_lists->>'#{list}' = 'true'"
      end.join(" OR ")
    )
  }
  scope :committee, -> { where(committee: true) }
  scope :without_emails, -> {
    left_outer_joins(:emails)
      .where(emails: { id: nil })
      .where.not(email: nil)
  }

  attr_accessor :skip_subscriptions

  validates :full_name, presence: true
  validates :address, presence: true

  def active_for_authentication?
    super && deactivated_at.nil?
  end

  def deactivated?
    deactivated_at.present?
  end

  def save_as_confirmed!
    self.confirmed_at ||= Time.current
    save!
  end

  def update_emails
    # fetch the email attribute directly from the table
    existing_email = read_attribute_before_type_cast('email')
    return if existing_email.blank? || email.present?

    new_email = Email.new(email: existing_email, user: self, primary: true)
    new_email.skip_confirmation!

    if new_email.save
      logger.info "Email updated for user #{id}: #{existing_email}"
    else
      logger.error "Failed to update email for user #{id}: #{new_email.errors.full_messages.join(', ')}"
    end
  end

  def update_mailing_list_and_memberships(email_update: false)
    subscribe_to_lists

    if email_update
      update_mailing_list_email_addresses
    else
      set_up_mailing_list_flags
    end

    return if memberships.current.any?

    memberships.create joined_at: Time.current
  end

  private

  def set_up_mailing_list_flags
    MailingList::Setup.call self
  end

  def subscribe_to_lists
    return if skip_subscriptions

    MailingList.each do |list|
      next unless mailing_lists[list.name] == "true"

      MailingList::Subscribe.call self, list
    end
  end

  def update_mailing_list_email_addresses
    MailingList.each do |list|
      next unless mailing_lists[list.name] == "true"

      MailingList::Update.call self, list
    end
  end
end
