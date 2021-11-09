# Rails Authentication from Scratch

## Step 1: Build User Model

1. Generate User model.

```bash
rails g model User email:string
```

```ruby
# db/migrate/[timestamp]_create_users.rb
class CreateUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      # Prevent blank values
      t.string :email, null: false

      t.timestamps
    end
    
    # Enforce unique values
    # https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/SchemaStatements.html#method-i-add_index
    add_index :users, :email, unique: true
  end
end
```

2. Add validations and callbacks.

```ruby
# app/models/user.rb
class User < ApplicationRecord
   VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

   before_save :downcase_email

   validates :email, format: { with: VALID_EMAIL_REGEX }, presence: true, uniqueness: true

   private

   def downcase_email
      self.email = self.email.downcase
   end
end
```

> **What's Going On Here?**
> 
> - We prevent empty values from being saved into the database through a `null: false` constraint in addition to the [presence](https://guides.rubyonrails.org/active_record_validations.html#presence) validation.
> - We enforce unique email addresses at the database level through `add_index :users, :email, unique: true` in addition to a [uniqueness](https://guides.rubyonrails.org/active_record_validations.html#uniqueness) validation.
> - We ensure all emails are valid through a [format](https://guides.rubyonrails.org/active_record_validations.html#format) validation.
> - We save all emails to the database in a downcase format via a [before_save](https://api.rubyonrails.org/v6.1.4/classes/ActiveRecord/Callbacks/ClassMethods.html#method-i-before_save) callback such that the values are saved in a consistent format.