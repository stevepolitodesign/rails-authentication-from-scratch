class ActiveSession < ApplicationRecord
  belongs_to :user

  has_secure_token :remember_token
end
