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
      t.string :email, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
```

2. Run migrations.

```bash
rails db:migrate
```

3. Add validations and callbacks.

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
> - We prevent empty values from being saved into the email column through a `null: false` constraint in addition to the [presence](https://guides.rubyonrails.org/active_record_validations.html#presence) validation.
> - We enforce unique email addresses at the database level through `add_index :users, :email, unique: true` in addition to a [uniqueness](https://guides.rubyonrails.org/active_record_validations.html#uniqueness) validation.
> - We ensure all emails are valid through a [format](https://guides.rubyonrails.org/active_record_validations.html#format) validation.
> - We save all emails to the database in a downcase format via a [before_save](https://api.rubyonrails.org/v6.1.4/classes/ActiveRecord/Callbacks/ClassMethods.html#method-i-before_save) callback such that the values are saved in a consistent format.

## Step 2: Add Confirmation and Password Columns to Users Table

1. Create migration.

```bash
rails g migration add_confirmation_and_password_columns_to_users confirmation_token:string confirmation_sent_at:datetime confirmed_at:datetime password_digest:string
```

2. Update the migration.

```ruby
# db/migrate/[timestamp]_add_confirmation_and_password_columns_to_users.rb
class AddConfirmationAndPasswordColumnsToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :confirmation_token, :string, null: false
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :confirmed_at, :datetime
    add_column :users, :password_digest, :string, null: false

    add_index :users, :confirmation_token, unique: true
  end
end
```

> **What's Going On Here?**
> 
> - The `confirmation_token` column will store a random value created through the [has_secure_token](https://api.rubyonrails.org/classes/ActiveRecord/SecureToken/ClassMethods.html#method-i-has_secure_token) method when a record is saved. This will be used to identify users in a secure way when we need to confirm their email address. We add `null: false` to prevent empty values and also add a unique index to ensure that no two users will have the same `confirmation_token`. You can think of this as a secure alternative to the `id` column.
> - The `confirmation_sent_at` column will be used to ensure a confirmation has not expired. This is an added layer of security to prevent a `confirmation_token` from being used multiple times.
> - The `confirmed_at` column will be set when a user confirms their account. This will help us determine who has confirmed their account and who has not.
> - The `password_digest` column will store a hashed version of the user's password. This is provided by the [has_secure_password(](https://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html#method-i-has_secure_password) method.

3. Run migrations.

```bash
rails db:migrate
```

4. Enable and install BCrypt.

This is needed to to use `has_secure_password`.

```ruby
# Gemfile
gem 'bcrypt', '~> 3.1.7'
```

```
bundle install
```

5. Update the User Model.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  CONFIRMATION_TOKEN_EXPIRATION_IN_SECONDS = 10.minutes.to_i
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  has_secure_password
  has_secure_token :confirmation_token

  before_save :downcase_email

  validates :email, format: { with: VALID_EMAIL_REGEX }, presence: true, uniqueness: true

  def confirm!
    self.update_columns(confirmed_at: Time.current)
  end

  def confirmed?
    self.confirmed_at.present?
  end

  def confirmation_token_has_not_expired?
    return false if self.confirmation_sent_at.nil?
    (Time.current - self.confirmation_sent_at) <= User::CONFIRMATION_TOKEN_EXPIRATION_IN_SECONDS
  end

  def unconfirmed?
    self.confirmed_at.nil?
  end

  private

  def downcase_email
    self.email = self.email.downcase
  end
end
```

> **What's Going On Here?**
> 
> - The `has_secure_password` method is added to give us an [API](https://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html#method-i-has_secure_password) to work with the `password_digest` column.
> - The `has_secure_token :confirmation_token` method is added to give us an [API](https://api.rubyonrails.org/classes/ActiveRecord/SecureToken/ClassMethods.html#method-i-has_secure_token) to work with the `confirmation_token` column.
> - The `confirm!` method will be called when a user confirms their email address. We still need to build this feature.
> - The `confirmed?` and `unconfirmed?` methods allow us to tell whether a user has confirmed their email address or not.
> - The `confirmation_token_has_not_expired?` method tells us if the confirmation token is expired or not. This can be controlled by changing the value of the `CONFIRMATION_TOKEN_EXPIRATION_IN_SECONDS` constant. This will be useful when we build the confirmation mailer.

## Step 3: Create Sign Up Pages

1. Create a simple home page since we'll need a place to redirect users to after they sign up.

```
rails g controller StaticPages home
```

2. Create UsersController.

```
rails g controller Users
```

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to root_path, notice: "Please check your email for confirmation instructions."
    else
      render :new
    end
  end

  def new
    @user = User.new
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
```

3. Build sign up form.

```html+ruby
<!-- app/views/shared/_form_errors.html.erb -->
<% if object.errors.any? %>
  <ul>
    <% object.errors.full_messages.each do |message| %>
      <li><%= message %></li>
    <% end %>
  </ul>
<% end %>
```

```html+ruby
<%= form_with model: @user, url: sign_up_path do |form| %>
  <%= render partial: "shared/form_errors", locals: { object: form.object } %>
  <div>
    <%= form.label :email %>
    <%= form.text_field :email, required: true %>
  </div>
  <div>
    <%= form.label :password %>
    <%= form.password_field :password, required: true %>
  </div>
  <div>
    <%= form.label :password_confirmation %>
    <%= form.password_field :password_confirmation, required: true %>
  </div>
  <%= form.submit %>
<% end %>
```

```
<!-- app/views/users/new.html.erb -->
<%= render "form" %>
```

4. Update routes.

```ruby
# config/routes.rb
Rails.application.routes.draw do
  root "static_pages#home"
  post "sign_up", to: "users#create"
  get "sign_up", to: "users#new"
end
```
## Step 4: Create Confirmation Pages

Users now have a way to sign up, but we need to verify their email address in order to prevent SPAM.

1. Create ConfirmationsController

```
rails g controller Confirmations
```

```ruby
# app/controllers/confirmations_controller.rb
class ConfirmationsController < ApplicationController

  def create
    @user = User.find_by(email: params[:user][:email].downcase)

    if @user && @user.unconfirmed?
      redirect_to root_path, notice: "Check your email for confirmation instructions."
    else
      redirect_to new_confirmation_path, alert: "We could not find a user with that email or that email has already been confirmed."
    end
  end

  def edit
    @user = User.find_by(confirmation_token: params[:confirmation_token])

    if @user && @user.confirmation_token_has_not_expired?
      @user.confirm!
      redirect_to root_path, notice: "Your account has been confirmed."
    else
      redirect_to new_confirmation_path, alert: "Invalid token."
    end
  end

  def new
    @user = User.new
  end

end
```

2. Build confirmation pages.

This page will be used in the case where a user did not receive their confirmation instructions and needs to have them resent.

```html+ruby
<!-- app/views/confirmations/new.html.erb -->
<%= form_with model: @user, url: confirmations_path do |form| %>
  <%= form.email_field :email, required: true %>
  <%= form.submit "Confirm Email" %>
<% end %>
```

3. Update routes.

```ruby
# config/routes.rb
Rails.application.routes.draw do
  ...
  resources :confirmations, only: [:create, :edit, :new], param: :confirmation_token
end
```

> **What's Going On Here?**
> 
> - The `create` action will be used to resend confirmation instructions to a user who is unconfirmed. We still need to build this mailer, and we still need to send this mailer when a user initially signs up. This action will be requested via the form on `app/views/confirmations/new.html.erb`. Note that we call `downcase` on the email to account for case sensitivity when searching.
> - The `edit` action is used to confirm a user's email. This will be the page that a user lands on when they click the confirmation link in their email. We still need to build this. Note that we're looking up a user through their `confirmation_token` and not their email or ID. This is because The `confirmation_token` is randomly generated and can't be easily guessed unlike an email or numeric ID. This is also why we added `param: :confirmation_token` as a [named route parameter](https://guides.rubyonrails.org/routing.html#overriding-named-route-parameters). Note that we check if their confirmation token has expired before confirming their account.

## Step 5: Create Confirmation Mailer

Now we need a way to send a confirmation email to our users in order for them to actually confirm their accounts.

1. Create confirmation mailer.

```bash
rails g mailer User confirmation 
```

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  default from: User::MAILER_FROM_EMAIL

  def confirmation(user)
    @user = user

    mail to: @user.email, subject: "Confirmation Instructions"
  end
end
```

```html+erb
<!-- app/views/user_mailer/confirmation.html.erb -->
<h1>Confirmation Instructions</h1>

<%= link_to "Click here to confirm your email.", edit_confirmation_url(@user.confirmation_token) %>
```

```text
<!-- app/views/user_mailer/confirmation.text.erb -->
Confirmation Instructions

<%= edit_confirmation_url(@user.confirmation_token) %>
```

2. Update User Model.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  ...
  MAILER_FROM_EMAIL = "no-reply@example.com"
  ...
  def send_confirmation_email!
    self.regenerate_confirmation_token
    self.update_columns(confirmation_sent_at: Time.current)
    UserMailer.confirmation(self).deliver_now
  end

end
```

> **What's Going On Here?**
> 
> - The `MAILER_FROM_EMAIL` constant is a way for us to set the email used in the `UserMailer`. This is optional.
> - The `send_confirmation_email!` method will create a new `confirmation_token` and update the value of `confirmation_sent_at`. This is to ensure confirmation links expire and cannot be reused. It will also send a the confirmation email to the user.
> - We call [update_columns](https://api.rubyonrails.org/classes/ActiveRecord/Persistence.html#method-i-update_columns) so that the `updated_at/updated_on` columns are not updated. This is personal preference, but those columns should typically only be updated when the user updates their email or password.
> - The links in the mailer will take the user to `ConfirmationsController#edit` at which point they'll be confirmed.

3. Configure Action Mailer so that links work locally.

Add a host to the test and development (and later the production) environments so that [urls will work in mailers](https://guides.rubyonrails.org/action_mailer_basics.html#generating-urls-in-action-mailer-views). 

```ruby
# config/environments/test.rb
Rails.application.configure do  
  ...
  config.action_mailer.default_url_options = { host: "example.com" }
end
```

```ruby
# config/environments/development.rb
Rails.application.configure do  
  ...
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
end
```

4. Update Controllers.

Now we can send a confirmation email when a user signs up or if they need to have it resent.

```ruby
# app/controllers/confirmations_controller.rb
class ConfirmationsController < ApplicationController

  def create
    @user = User.find_by(email: params[:user][:email].downcase)

    if @user && @user.unconfirmed?
      @user.send_confirmation_email!
      ...
    end
  end

end
```

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController

  def create
    @user = User.new(user_params)
    if @user.save
      @user.send_confirmation_email!
      ...
    end
  end

end
```

## Step 6: Create Current Model and Authentication Concern

1. Create a model to store the current user.

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :user
end
```

2. Create a Concern to store helper methods that will be shared accross the application.

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :current_user
    helper_method :current_user
    helper_method :user_signed_in?
  end

  def login(user)
    reset_session
    session[:current_user_id] = user.id
  end

  def logout
    reset_session
  end

  def redirect_if_authenticated
    redirect_to root_path, alert: "You are already logged in." if user_signed_in?
  end

  private

  def current_user
    Current.user = session[:current_user_id] && User.find_by(id: session[:current_user_id])
  end

  def user_signed_in?
    Current.user.present?
  end

end
```

3. Load the Authentication Concern into the Application Controller.

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Authentication
end
```

> **What's Going On Here?**
> 
> - The `Current` class inherits from [ActiveSupport::CurrentAttributes](https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html) which allows us to keep all per-request attributes easily available to the whole system. In essence this will allow us to set a current user and have access to that user during each request to the server. 
> - The `Authentication` Concern provides an interface for logging the user in and out. We load it into the `ApplicationController` so that it will be used acrosss the whole application.
>   - The `login` method first [resets the session](https://api.rubyonrails.org/classes/ActionController/Metal.html#method-i-reset_session) to account for [session fixation](https://guides.rubyonrails.org/security.html#session-fixation-countermeasures).
>   - We set the user's ID in the [session](https://guides.rubyonrails.org/action_controller_overview.html#session) so that we can have access to the user across requests. The user's ID won't be stored in plain text. The cookie data is cryptographically signed to make it tamper-proof. And it is also encrypted so anyone with access to it can't read its contents.
>   - The `logout` method simply [resets the session](https://api.rubyonrails.org/classes/ActionController/Metal.html#method-i-reset_session).
>   - The `redirect_if_authenticated` method checks to see if the user is logged in. If they are, they'll be redirected to the `root_path`. This will be useful on pages an authenticated user should not be able to access, such as the login page.
>   - The `current_user` method returns a `User` and sets it as the user on the `Current` class we created. We call the `before_action` [filter](https://guides.rubyonrails.org/action_controller_overview.html#filters) so that we have access to the current user before each request. We also add this as a [helper_method](https://api.rubyonrails.org/classes/AbstractController/Helpers/ClassMethods.html#method-i-helper_method) so that we have access to `current_user` in the views.
>   - The `user_signed_in?` method simply returns true or false depending on whether the user is signed in or not. This is helpful for conditionally rendering items in views. 

## Step 7: Create Login Page

1. Generate Sessions Controller.

```bash
rails g controller Sessions
```

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  before_action :redirect_if_authenticated, only: [:create, :new]

  def create
    @user = User.find_by(email: params[:user][:email].downcase)
    if @user
      if @user.unconfirmed?
        redirect_to new_confirmation_path, alert: "You must confirm your email before you can sign in."
      elsif @user.authenticate(params[:user][:password])
        login @user
        redirect_to root_path, notice: "Signed in."
      else
        flash[:alert] = "Incorrect email or password."
        render :new        
      end
    else
      flash[:alert] = "Incorrect email or password."
      render :new
    end
  end

  def destroy
    logout
    redirect_to root_path, notice: "Singed out."
  end

  def new
  end

end
```

2. Update routes.

```ruby
# config/routes.rb
Rails.application.routes.draw do
  ...
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  get "login", to: "sessions#new"
end
```

3. Add sign in form.

```html+ruby
<!-- app/views/sessions/new.html.erb -->
<%= form_with url: login_path, scope: :user do |form| %>
  <div>
    <%= form.label :email %>
    <%= form.text_field :email, required: true %>
  </div>
  <div>
    <%= form.label :password %>
    <%= form.password_field :password, required: true %>
  </div>
  <div>
    <%= form.label :password_confirmation %>
    <%= form.password_field :password_confirmation, required: true %>
  </div>
  <%= form.submit %>
<% end %>
```

> **What's Going On Here?**
> 
> - The `create` method simply simply checks if the user exists and is confirmed. If they are, then we check their password. If the password is correct, we log them in via the `login` method we created in the `Authentication` Concern. Otherwise, we render a an alert.  
>   - We're able to call `user.authenticate` because of [has_secure_password](https://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html#method-i-has_secure_password)
>   - Note that we call `downcase` on the email to account for case sensitivity when searching.
> - The `destroy` method simply calls the `logout` method we created in the `Authentication` Concern.
> - The login form is passed a `scope: :user` option so that the params are namespaced as `params[:user][:some_value]`. This is not required, but it helps keep thins organized. 

## Step 8: Update Existing Controllers

1. Updated Controllers to prevent authenticated users from accessing pages intended for anonymous users.

```ruby
# app/controllers/confirmations_controller.rb
class ConfirmationsController < ApplicationController
  before_action :redirect_if_authenticated

  def edit
    ...
    if @user && @user.confirmation_token_has_not_expired?
      @user.confirm!
      login @user
      ...  
    else
    end
    ...
  end
end
```

Note that we also call `login @user` once a user is confirmed. That way they'll be automatically logged in after confirming their email.

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController
  before_action :redirect_if_authenticated, only: [:create, :new]
  ...
end
```
