class User < ApplicationRecord
   VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

   before_save :downcase_email

   validates :email, format: { with: VALID_EMAIL_REGEX }, presence: true, uniqueness: true

   private

   def downcase_email
      self.email = self.email.downcase
   end
end
