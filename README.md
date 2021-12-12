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
  before_save :downcase_email

  validates :email,
    format: { with: URI::MailTo::EMAIL_REGEXP },
    presence: true,
    uniqueness: true

  private

  def downcase_email
    email = email.downcase
  end
end
```

> **What's Going On Here?**
>
> - We prevent empty values from being saved into the email column through a `null: false` constraint in addition to the [presence](https://guides.rubyonrails.org/active_record_validations.html#presence) validation.
> - We enforce unique email addresses at the database level through `add_index :users, :email, unique: true` in addition to a [uniqueness](https://guides.rubyonrails.org/active_record_validations.html#uniqueness) validation.
> - We ensure all emails are valid through a [format](https://guides.rubyonrails.org/active_record_validations.html#format) validation.
> - We save all emails to the database in a downcase format via a [before_save](https://api.rubyonrails.org/v6.1.4/classes/ActiveRecord/Callbacks/ClassMethods.html#method-i-before_save) callback such that the values are saved in a consistent format.
> - We use [URI::MailTo::EMAIL_REGEXP](https://ruby-doc.org/stdlib-3.0.0/libdoc/uri/rdoc/URI/MailTo.html) that comes with Ruby to valid that the email address is properly formatted.

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

  validates :email, format: {with: VALID_EMAIL_REGEX}, presence: true, uniqueness: true

  def confirm!
    update_columns(confirmed_at: Time.current)
  end

  def confirmed?
    confirmed_at.present?
  end

  def confirmation_token_has_not_expired?
    return false if confirmation_sent_at.nil?
    (Time.current - confirmation_sent_at) <= User::CONFIRMATION_TOKEN_EXPIRATION_IN_SECONDS
  end

  def unconfirmed?
    !confirmed?
  end

  private

  def downcase_email
    email = email.downcase
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
<!-- app/views/users/new.html.erb -->
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

    if @user.present? && @user.unconfirmed?
      redirect_to root_path, notice: "Check your email for confirmation instructions."
    else
      redirect_to new_confirmation_path, alert: "We could not find a user with that email or that email has already been confirmed."
    end
  end

  def edit
    @user = User.find_by(confirmation_token: params[:confirmation_token])

    if @user.present? && @user.confirmation_token_has_not_expired?
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
    regenerate_confirmation_token
    update_columns(confirmation_sent_at: Time.current)
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

    if @user.present? && @user.unconfirmed?
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
  <%= form.submit %>
<% end %>
```

> **What's Going On Here?**
>
> - The `create` method simply simply checks if the user exists and is confirmed. If they are, then we check their password. If the password is correct, we log them in via the `login` method we created in the `Authentication` Concern. Otherwise, we render a an alert.
>   - We're able to call `user.authenticate` because of [has_secure_password](https://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html#method-i-has_secure_password)
>   - Note that we call `downcase` on the email to account for case sensitivity when searching.
> - The `destroy` method simply calls the `logout` method we created in the `Authentication` Concern.
> - The login form is passed a `scope: :user` option so that the params are namespaced as `params[:user][:some_value]`. This is not required, but it helps keep things organized.

## Step 8: Update Existing Controllers

1. Updated Controllers to prevent authenticated users from accessing pages intended for anonymous users.

```ruby
# app/controllers/confirmations_controller.rb
class ConfirmationsController < ApplicationController
  before_action :redirect_if_authenticated, only: [:create, :new]

  def edit
    ...
    if @user.present? && @user.confirmation_token_has_not_expired?
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

## Step 9: Add Password Reset Columns to Users Table

1. Create migration.

```bash
rails g migration add_password_reset_token_to_users password_reset_token:string password_reset_sent_at:datetime
```

2. Update the migration.

```ruby
# db/migrate/[timestamp]_add_password_reset_token_to_users.rb
class AddPasswordResetTokenToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :password_reset_token, :string, null: false
    add_column :users, :password_reset_sent_at, :datetime
    add_index :users, :password_reset_token, unique: true
  end
end
```

> **What's Going On Here?**
>
> - The `password_reset_token` column will store a random value created through the [has_secure_token](https://api.rubyonrails.org/classes/ActiveRecord/SecureToken/ClassMethods.html#method-i-has_secure_token) method when a record is saved. This will be used to identify users in a secure way when they need to reset their password. We add `null: false` to prevent empty values and also add a unique index to ensure that no two users will have the same `password_reset_token`. You can think of this as a secure alternative to the `id` column.
> - The `password_reset_sent_at` column will be used to ensure a password reset link has not expired. This is an added layer of security to prevent a `password_reset_token` from being used multiple times.

3. Run migration.

```bash
rails db:migrate
```

4. Update User Model.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  ...
  PASSWORD_RESET_TOKEN_EXPIRATION_IN_SECONDS = 10.minutes.to_i
  ...
  has_secure_token :password_reset_token
  ...
  def password_reset_token_has_expired?
    return true if password_reset_sent_at.nil?
    (Time.current - password_reset_sent_at) >= User::PASSWORD_RESET_TOKEN_EXPIRATION_IN_SECONDS
  end

  def send_password_reset_email!
    regenerate_password_reset_token
    update_columns(password_reset_sent_at: Time.current)
    UserMailer.password_reset(self).deliver_now
  end
  ...
end
```

5. Update User Mailer.

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  ...
  def password_reset(user)
    @user = user

    mail to: @user.email, subject: "Password Reset Instructions"
  end
end

```

> **What's Going On Here?**
>
> - The `has_secure_token :password_reset_token` method is added to give us an [API](https://api.rubyonrails.org/classes/ActiveRecord/SecureToken/ClassMethods.html#method-i-has_secure_token) to work with the `password_reset_token` column.
> - The `password_reset_token_has_expired?` method tells us if the password reset token is expired or not. This can be controlled by changing the value of the `PASSWORD_RESET_TOKEN_EXPIRATION_IN_SECONDS` constant. This will be useful when we build the password reset mailer.
> - The `send_password_reset_email!` method will create a new `password_reset_token` and update the value of `password_reset_sent_at`. This is to ensure password reset links expire and cannot be reused. It will also send a the password reset email to the user. We still need to build this.

## Step 10: Build Password Reset Forms

1. Create PasswordsController.

```bash
rails g controller Passwords
```

```ruby
# app/controllers/passwords_controller.rb
class PasswordsController < ApplicationController
  before_action :redirect_if_authenticated

  def create
    @user = User.find_by(email: params[:user][:email].downcase)
    if @user.present?
      if @user.confirmed?
        @user.send_password_reset_email!
        redirect_to root_path, notice: "If that user exists we've sent instructions to their email."
      else
        redirect_to new_confirmation_path, alert: "Please confirm your email first."
      end
    else
      redirect_to root_path, notice: "If that user exists we've sent instructions to their email."
    end
  end

  def edit
    @user = User.find_by(password_reset_token: params[:password_reset_token])
    if @user.present? && @user.unconfirmed?
      redirect_to new_confirmation_path, alert: "You must confirm your email before you can sign in."
    elsif @user.nil? || @user.password_reset_token_has_expired?
      redirect_to new_password_path, alert: "Invalid or expired token."
    end
  end

  def new
  end

  def update
    @user = User.find_by(password_reset_token: params[:password_reset_token])
    if @user
      if @user.unconfirmed?
        redirect_to new_confirmation_path, alert: "You must confirm your email before you can sign in."
      elsif @user.password_reset_token_has_expired?
        redirect_to new_password_path, alert: "Incorrect email or password."
      elsif @user.update(password_params)
        redirect_to login_path, notice: "Signed in."
      else
        flash[:alert] = @user.errors.full_messages.to_sentence
        render :edit
      end
    else
      flash[:alert] = "Incorrect email or password."
      render :new
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
```

> **What's Going On Here?**
>
> - The `create` action will send an email to the user containing a link that will allow them to reset the password. The link will contain their `password_reset_token` which is unique and expires. Note that we call `downcase` on the email to account for case sensitivity when searching.
>   - Note that we return `If that user exists we've sent instructions to their email.` even if the user is not found. This makes it difficult for a bad actor to use the reset form to see which email accounts exist on the application.
> - The `edit` action renders simply renders the form for the user to update their password. It attempts to find a user by there `password_reset_token`. You can think of the `password_reset_token` as a way to identify the user  much like how we normally identify records by their ID. However, the `password_reset_token` is randomly generated and will expire so it's more secure.
> - The `new` action simply renders a form for the user to put their email address in to receive the password reset email.
> - The `update` also ensures the user is identified by their `password_reset_token`. It's not enough to just do this on the `edit` action since a bad actor could make a `PUT` request to the server and bypass the form.
>   - If the user exists and is confirmed and their password token has not expired, we update their password to the one they will set in the form. Otherwise we handle each failure case a little different.

2. Update Routes.

```ruby
# config/routes.rb
Rails.application.routes.draw do
  ...
  resources :passwords, only: [:create, :edit, :new, :update], param: :password_reset_token
end
```

> **What's Going On Here?**
>
> -  We add `param: :password_reset_token` as a [named route parameter](https://guides.rubyonrails.org/routing.html#overriding-named-route-parameters) to the so that we can identify users by their `password_reset_token` and not `id`. This is similar to what we did with the confirmations routes, and ensures a user cannot be identified by their ID.

3. Build forms.

```html+ruby
<!-- app/views/passwords/new.html.erb -->
<%= form_with url: passwords_path, scope: :user do |form| %>
  <%= form.email_field :email, required: true %>
  <%= form.submit "Reset Password" %>
<% end %>
```

```html+ruby
<!-- app/views/passwords/edit.html.erb -->
<%= form_with url: password_path(@user.password_reset_token), scope: :user, method: :put do |form| %>
  <div>
    <%= form.label :password %>
    <%= form.password_field :password, required: true %>
  </div>
  <div>
    <%= form.label :password_confirmation %>
    <%= form.password_field :password_confirmation, required: true %>
  </div>
  <%= form.submit "Update Password" %>
<% end %>
```

> **What's Going On Here?**
>
> - The password reset form is passed a `scope: :user` option so that the params are namespaced as `params[:user][:some_value]`. This is not required, but it helps keep things organized.

## Step 11: Add Unconfirmed Email Column To Users Table

1. Create migration and run migration

```bash
rails g migration add_unconfirmed_email_to_users unconfirmed_email:string
rails db:migrate
```

2. Update User Model.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  ...
  attr_accessor :current_password
  ...
  before_save :downcase_unconfirmed_email
  ...
  validates :unconfirmed_email, format: {with: VALID_EMAIL_REGEX, allow_blank: true}
  validate :unconfirmed_email_must_be_available

  def confirm!
    if unconfirmed_email.present?
      update(email: unconfirmed_email, unconfirmed_email: nil)
    end
    update_columns(confirmed_at: Time.current)
  end
  ...
  def confirmable_email
    if unconfirmed_email.present?
      unconfirmed_email
    else
      email
    end
  end
  ...
  def reconfirming?
    unconfirmed_email.present?
  end

  def unconfirmed_or_reconfirming?
    unconfirmed? || reconfirming?
  end

  private
  ...
  def downcase_unconfirmed_email
    return if unconfirmed_email.nil?
    unconfirmed_email = unconfirmed_email.downcase
  end

  def unconfirmed_email_must_be_available
    return if unconfirmed_email.nil?
    if User.find_by(email: unconfirmed_email.downcase)
      errors.add(:unconfirmed_email, "is already in use.")
    end
  end

end
```

3. Update User Mailer.

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer

  def confirmation(user)
    ...
    mail to: @user.confirmable_email, subject: "Confirmation Instructions"
  end
end

```

> **What's Going On Here?**
>
> - We add a `unconfirmed_email` to the `users_table` so that we have a place to store the email a user is trying to use after their account has been confirmed with their original email.
> - We add `attr_accessor :current_password` so that we'll be able to use `f.password_field :current_password` in the user form (which doesn't exist yet). This will allow us to require the user to submit their current password before they can update their account.
> - We ensure to format the `unconfirmed_email` before saving to the database. This ensures all data is saved consistently.
> - We add validations to the `unconfirmed_email` column ensuring it's a valid email address and that it's not currently in use.
> - We update the `confirm!` method to set the `email` column to the value of the `unconfirmed_email` column, and then clear out the `unconfirmed_email` column. This will only happen if a user is trying to confirm a new email address.
> - We add the `confirmable_email` method so that we can call the correct email in the the updated `UserMailer`.
> - We add `reconfirming?` and `unconfirmed_or_reconfirming?` to help us determine what state a user is in. This will come in handy later in our controllers.

## Step 12: Update Users Controller

1. Update Authentication Concern

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  ...
  def authenticate_user!
    redirect_to login_path, alert: "You need to login to access that page." unless user_signed_in?
  end
  ...
end
```

> **What's Going On Here?**
>
> - The `authenticate_user!` method can be called to ensure an anonymous user cannot access a page that requires a user to be logged in. We'll need this when we build the page allowing a user to edit or delete their profile.

2. Add destroy, edit and update methods. Modify create method and user_params.

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController
  before_action :authenticate_user!, only: [:edit, :destroy, :update]
  ...
  def create
    @user = User.new(create_user_params)
    ...
  end

  def destroy
    current_user.destroy
    reset_session
    redirect_to root_path, notice: "Your account has been deleted."
  end

  def edit
    @user = current_user
  end
  ...
  def update
    @user = current_user
    if @user.authenticate(params[:user][:current_password])
      if @user.update(update_user_params)
        if params[:user][:unconfirmed_email].present?
          @user.send_confirmation_email!
          redirect_to root_path, notice: "Check your email for confirmation instructions."
        else
          redirect_to root_path, notice: "Account updated."
        end
      else
        render :edit, status: :unprocessable_entity
      end
    else
      flash.now[:error] = "Incorrect password"
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def create_user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  def update_user_params
    params.require(:user).permit(:current_password, :password, :password_confirmation, :unconfirmed_email)
  end
end
```

> **What's Going On Here?**
>
> - We call `redirect_if_authenticated` before editing, destroying or updating a user, since only an authenticated use should be able to do this.
> - We update the `create` method to accept `create_user_params` (formerly `user_params`). This is because we're going to require different parameters for creating an account vs. editing an account.
> - The `destroy` action simply deletes the user and logs them out. Note that we're calling `current_user`, so this action can only be scoped to the user who is logged in.
> - The `edit` action simply assigns `@user` to the `current_user` so that we have access to the user in the edit form.
> - The `update` action first checks if their password is correct. Note that we're passing this in as `current_password` and not `password`. This is because we still want a user to be able to change their password and therefor we need another parameter to store this value. This is also why we have a private `update_user_params` method.
>   - If the user is updating their email address (via `unconfirmed_email`) we send a confirmation email to that new email address before setting it as the `email` value.
>   - We force a user to always put in their `current_password` as an extra security measure incase someone leaves their browser open on a public computer.

3. Update routes.

```ruby
# config/routes.rb
Rails.application.routes.draw do
  ...
  put "account", to: "users#update"
  get "account", to: "users#edit"
  delete "account", to: "users#destroy"
  ...
end
```

4. Create edit form.

```html+ruby
<!-- app/views/users/edit.html.erb -->
<%= form_with model: @user, url: account_path, method: :put do |form| %>
  <%= render partial: "shared/form_errors", locals: { object: form.object } %>
  <div>
    <%= form.label :email, "Current Email" %>
    <%= form.text_field :email, disabled: true %>
  </div>
  <div>
    <%= form.label :unconfirmed_email, "New Email" %>
    <%= form.text_field :unconfirmed_email %>
  </div>
  <div>
    <%= form.label :password, "Password (leave blank if you don't want to change it)" %>
    <%= form.password_field :password %>
  </div>
  <div>
    <%= form.label :password_confirmation %>
    <%= form.password_field :password_confirmation %>
  </div>
  <hr/>
  <div>
    <%= form.label :current_password, "Current password (we need your current password to confirm your changes)" %>
    <%= form.password_field :current_password, required: true %>
  </div>
  <%= form.submit %>
<% end %>
```

> **What's Going On Here?**
>
> - We `disable` the `email` field to ensure we're not passing that value back to the controller. This is just so the user can see what their current email is.
> - We `require` the `current_password` field since we'll always want to a user to confirm their password before making changes.
> - The `password` and `password_confirmation` fields are there if a user wants to update their current password.

## Step 13: Update Confirmations Controller

1. Update edit action.

```ruby
# app/controllers/confirmations_controller.rb
class ConfirmationsController < ApplicationController
  ...
  def edit
    ...
    if @user.present? && @user.unconfirmed_or_reconfirming? && @user.confirmation_token_has_not_expired?
      ...
    end
  end
  ...
end
```

> **What's Going On Here?**
>
> - We add `@user.unconfirmed_or_reconfirming?` to the conditional to ensure only unconfirmed users or users who are reconfirming can access this page. This is necessary since we're now allowing users to confirm new email addresses.

## Step 14: Add Remember Token Column to Users Table

1. Create migration.

```bash
rails g migration add_remember_token_to_users remember_token:string
```

2. Update migration.

```ruby
# db/migrate/[timestamp]_add_remember_token_to_users.rb
class AddRememberTokenToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :remember_token, :string, null: false
    add_index :users, :remember_token, unique: true
  end
end
```

> **What's Going On Here?**
>
> - We add `null: false` to ensure this column always has a value.
> - We add a [unique index](https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/Table.html#method-i-index) to ensure this column has unique data.

3. Run migrations.

```bash
rails db:migrate
```

4. Update User model.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  ...
  has_secure_token :remember_token
  ...
end
```

> **What's Going On Here?**
>
> - Just like the `confirmation_token` and `password_reset_token` columns, we call [has_secure_token](https://api.rubyonrails.org/classes/ActiveRecord/SecureToken/ClassMethods.html#method-i-has_secure_token) on the `remember_token`. This ensures that the value for this column will be set when the record is created. This value will be used later to securely identify the user.

## Step 15: Update Authentication Concern

1. Add new helper methods.

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  extend ActiveSupport::Concern
  ...
  def forget(user)
    cookies.delete :remember_token
    user.regenerate_remember_token
  end
  ...
  def remember(user)
    user.regenerate_remember_token
    cookies.permanent.encrypted[:remember_token] = user.remember_token
  end
  ...
  private

  def current_user
    Current.user = if session[:current_user_id].present?
      User.find_by(id: session[:current_user_id])
    elsif cookies.permanent.encrypted[:remember_token].present?
      User.find_by(remember_token: cookies.permanent.encrypted[:remember_token])
    end
  end
  ...
end
```

> **What's Going On Here?**
>
> - The `remember` method first regenerates a new `remember_token` to ensure these values are being rotated and can't be used more than once. We get the `regenerate_remember_token` method from [has_secure_token](https://api.rubyonrails.org/classes/ActiveRecord/SecureToken/ClassMethods.html#method-i-has_secure_token). Next, we assigned this value to a [cookie](https://api.rubyonrails.org/classes/ActionDispatch/Cookies.html). The call to [permanent](https://api.rubyonrails.org/classes/ActionDispatch/Cookies/ChainedCookieJars.html#method-i-permanent) ensures the cookie won't expire until 20 years from now. The call to [encrypted](https://api.rubyonrails.org/classes/ActionDispatch/Cookies/ChainedCookieJars.html#method-i-encrypted) ensures the value will be encrypted. This is vital since this value is used to identify the user and is being set in the browser.
> - The `forget` method deletes the cookie and regenerates a new `remember_token` to ensure these values are being rotated and can't be used more than once.
> - We updated the `current_user` method by adding a conditional to first try and find the user by the session, and then fallback to finding the user be the cookie. This is the logic that allows a user to completely exit their browser and still remain logged in when they return to the website since the cookie will still be set.

## Step 16: Update Sessions Controller

1. Update the `create` and `destroy` methods.

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  ...
  before_action :authenticate_user!, only: [:destroy]

  def create
    ...
    if @user
      if @user.unconfirmed?
        ...
      elsif @user.authenticate(params[:user][:password])
        login @user
        remember(@user) if params[:user][:remember_me] == "1"
        ...
      else
        ...
      end
    else
      ...
    end
  end

  def destroy
    forget(current_user)
    ...
  end
  ...
end
```

> **What's Going On Here?**
>
> - We conditionally call `remember(@user)` in the `create` method if the user has checked the "Remember me" checkbox. We still need to add this to our form.
> - We call `forget(current_user)` in the `destroy` method to ensure we delete the `remember_me` cookie and regenerate the user's `remember_token` token.
> - We also add a `before_action` to ensure only authenticated users can access the `destroy` action.

2. Add "Remember me" checkbox to login form.

```html+ruby
<!-- app/views/sessions/new.html.erb -->
<%= form_with url: login_path, scope: :user do |form| %>
  ...
  <div>
    <%= form.label :remember_me %>
    <%= form.check_box :remember_me %>
  </div>
  <%= form.submit %>
<% end %>
```

## Step 15: Add Friendly Redirects

1. Update Authentication Concern.

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  ...
  def authenticate_user!
    store_location
    ...
  end
  ...
  def store_location
    session[:user_return_to] = request.original_url if request.get?
  end
  ...
end
```

> **What's Going On Here?**
>
> - The `store_location` method stores the [request.original_url](https://api.rubyonrails.org/classes/ActionDispatch/Request.html#method-i-original_url) in the [session](https://guides.rubyonrails.org/action_controller_overview.html#session) so it can be retrieved later. We only do this if the request made was a get request.
> - We call `store_location` in the `authenticate_user!` method so that we can save the path to the page the user was trying to visit before they were redirected to the login page. We need to do this before visiting the login page otherwise the call to `request.original_url` will always return the url to the login page.

2. Update Sessions Controller.

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  ...
  def create
    ...
    if @user
      if @user.unconfirmed?
        ...
      elsif @user.authenticate(params[:user][:password])
        after_login_path = session[:user_return_to] || root_path
        login @user
        remember(@user) if params[:user][:remember_me] == "1"
        redirect_to after_login_path, notice: "Signed in."
      else
        ...
      end
    else
      ...
    end
  end
  ...
end
```

> **What's Going On Here?**
>
> - The `after_login_path` variable it set to be whatever is in the `session[:user_return_to]`. If there's nothing in `session[:user_return_to]` then it defaults to the `root_path`.
> - Note that we call this method before calling `login`. This is because `login` calls `reset_session` which would deleted the `session[:user_return_to]`.