# Rails Authentication from Scratch

If you're like me then you probably take Devise for granted because you're too intimidated to roll your own authentication system. As powerful as Devise is, it's not perfect. There are plenty of cases where I've reached for it only to end up constrained by its features and design, and wished I could customize it exactly to my liking.

Fortunately, Rails gives you all the tools you need to roll your own authentication system from scratch without needing to depend on a gem. The challenge is just knowing how to account for edge cases while being cognizant of security and best practices.

## Previous Versions

This guide is continuously updated to account for best practices. You can [view previous releases here](https://github.com/stevepolitodesign/rails-authentication-from-scratch/releases).

## Local Development

Simply run the setup script and follow the prompts to see the final application.

```bash
./bin/setup
```

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

  validates :email, format: {with: URI::MailTo::EMAIL_REGEXP}, presence: true, uniqueness: true

  private

  def downcase_email
    self.email = email.downcase
  end
end
```

> **What's Going On Here?**
>
> - We prevent empty values from being saved into the email column through a `null: false` constraint in addition to the [presence](https://guides.rubyonrails.org/active_record_validations.html#presence) validation.
> - We enforce unique email addresses at the database level through `add_index :users, :email, unique: true` in addition to a [uniqueness](https://guides.rubyonrails.org/active_record_validations.html#uniqueness) validation.
> - We ensure all emails are valid through a [format](https://guides.rubyonrails.org/active_record_validations.html#format) validation.
> - We save all emails to the database in a downcase format via a [before_save](https://api.rubyonrails.org/v6.1.4/classes/ActiveRecord/Callbacks/ClassMethods.html#method-i-before_save) callback such that the values are saved in a consistent format.
> - We use [URI::MailTo::EMAIL_REGEXP](https://ruby-doc.org/stdlib-3.0.0/libdoc/uri/rdoc/URI/MailTo.html) that comes with Ruby to validate that the email address is properly formatted.

## Step 2: Add Confirmation and Password Columns to Users Table

1. Create migration.

```bash
rails g migration add_confirmation_and_password_columns_to_users confirmed_at:datetime password_digest:string
```

2. Update the migration.

```ruby
# db/migrate/[timestamp]_add_confirmation_and_password_columns_to_users.rb
class AddConfirmationAndPasswordColumnsToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :confirmed_at, :datetime
    add_column :users, :password_digest, :string, null: false
  end
end
```

> **What's Going On Here?**
>
> - The `confirmed_at` column will be set when a user confirms their account. This will help us determine who has confirmed their account and who has not.
> - The `password_digest` column will store a hashed version of the user's password. This is provided by the [has_secure_password](https://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html#method-i-has_secure_password) method.

3. Run migrations.

```bash
rails db:migrate
```

4. Enable and install BCrypt.

This is needed to use `has_secure_password`.

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
  CONFIRMATION_TOKEN_EXPIRATION = 10.minutes

  has_secure_password

  before_save :downcase_email

  validates :email, format: {with: URI::MailTo::EMAIL_REGEXP}, presence: true, uniqueness: true

  def confirm!
    update_columns(confirmed_at: Time.current)
  end

  def confirmed?
    confirmed_at.present?
  end

  def generate_confirmation_token
    signed_id expires_in: CONFIRMATION_TOKEN_EXPIRATION, purpose: :confirm_email
  end

  def unconfirmed?
    !confirmed?
  end

  private

  def downcase_email
    self.email = email.downcase
  end
end
```

> **What's Going On Here?**
>
> - The `has_secure_password` method is added to give us an [API](https://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html#method-i-has_secure_password) to work with the `password_digest` column.
> - The `confirm!` method will be called when a user confirms their email address. We still need to build this feature.
> - The `confirmed?` and `unconfirmed?` methods allow us to tell whether a user has confirmed their email address or not.
> - The `generate_confirmation_token` method creates a [signed_id](https://api.rubyonrails.org/classes/ActiveRecord/SignedId.html#method-i-signed_id) that will be used to securely identify the user. For added security, we ensure that this ID will expire in 10 minutes (this can be controlled with the `CONFIRMATION_TOKEN_EXPIRATION` constant) and give it an explicit purpose of `:confirm_email`. This will be useful when we build the confirmation mailer.

## Step 3: Create Sign Up Pages

1. Create a simple home page since we'll need a place to redirect users to after they sign up.

```
rails g controller StaticPages home
```

2. Create Users Controller.

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
      render :new, status: :unprocessable_entity
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

3. Build sign-up form.

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
    <%= form.email_field :email, required: true %>
  </div>
  <div>
    <%= form.label :password %>
    <%= form.password_field :password, required: true %>
  </div>
  <div>
    <%= form.label :password_confirmation %>
    <%= form.password_field :password_confirmation, required: true %>
  </div>
  <%= form.submit "Sign Up" %>
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

Users now have a way to sign up, but we need to verify their email address to prevent SPAM.

1. Create Confirmations Controller.

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
    @user = User.find_signed(params[:confirmation_token], purpose: :confirm_email)

    if @user.present?
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
> - The `create` action will be used to resend confirmation instructions to an unconfirmed user. We still need to build this mailer, and we still need to send this mailer when a user initially signs up. This action will be requested via the form on `app/views/confirmations/new.html.erb`. Note that we call `downcase` on the email to account for case sensitivity when searching.
> - The `edit` action is used to confirm a user's email. This will be the page that a user lands on when they click the confirmation link in their email. We still need to build this. Note that we're looking up a user through the [find_signed](https://api.rubyonrails.org/classes/ActiveRecord/SignedId/ClassMethods.html#method-i-find_signed) method and not their email or ID. This is because The `confirmation_token` is randomly generated and can't be guessed or tampered with unlike an email or numeric ID. This is also why we added `param: :confirmation_token` as a [named route parameter](https://guides.rubyonrails.org/routing.html#overriding-named-route-parameters).
>  - You'll remember that the `confirmation_token` is a [signed_id](https://api.rubyonrails.org/classes/ActiveRecord/SignedId.html#method-i-signed_id), and is set to expire in 10 minutes. You'll also note that we need to pass the method `purpose: :confirm_email` to be consistent with the purpose that was set in the `generate_confirmation_token` method. 

## Step 5: Create Confirmation Mailer

Now we need a way to send a confirmation email to our users for them to actually confirm their accounts.

1. Create a confirmation mailer.

```bash
rails g mailer User confirmation
```

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  default from: User::MAILER_FROM_EMAIL

  def confirmation(user, confirmation_token)
    @user = user
    @confirmation_token = confirmation_token

    mail to: @user.email, subject: "Confirmation Instructions"
  end
end
```

```html+erb
<!-- app/views/user_mailer/confirmation.html.erb -->
<h1>Confirmation Instructions</h1>

<%= link_to "Click here to confirm your email.", edit_confirmation_url(@confirmation_token) %>
```

```html+erb
<!-- app/views/user_mailer/confirmation.text.erb -->
Confirmation Instructions

<%= edit_confirmation_url(@confirmation_token) %>
```

2. Update User Model.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  ...
  MAILER_FROM_EMAIL = "no-reply@example.com"
  ...
  def send_confirmation_email!
    confirmation_token = generate_confirmation_token
    UserMailer.confirmation(self, confirmation_token).deliver_now
  end

end
```

> **What's Going On Here?**
>
> - The `MAILER_FROM_EMAIL` constant is a way for us to set the email used in the `UserMailer`. This is optional.
> - The `send_confirmation_email!` method will create a new `confirmation_token`. This is to ensure confirmation links expire and cannot be reused. It will also send the confirmation email to the user.
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

2. Create a Concern to store helper methods that will be shared across the application.

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
    Current.user ||= session[:current_user_id] && User.find_by(id: session[:current_user_id])
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
> - The `Current` class inherits from [ActiveSupport::CurrentAttributes](https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html) which allows us to keep all per-request attributes easily available to the whole system. In essence, this will allow us to set a current user and have access to that user during each request to the server.
> - The `Authentication` Concern provides an interface for logging the user in and out. We load it into the `ApplicationController` so that it will be used across the whole application.
>   - The `login` method first [resets the session](https://api.rubyonrails.org/classes/ActionController/Metal.html#method-i-reset_session) to account for [session fixation](https://guides.rubyonrails.org/security.html#session-fixation-countermeasures).
>   - We set the user's ID in the [session](https://guides.rubyonrails.org/action_controller_overview.html#session) so that we can have access to the user across requests. The user's ID won't be stored in plain text. The cookie data is cryptographically signed to make it tamper-proof. And it is also encrypted so anyone with access to it can't read its contents.
>   - The `logout` method simply [resets the session](https://api.rubyonrails.org/classes/ActionController/Metal.html#method-i-reset_session).
>   - The `redirect_if_authenticated` method checks to see if the user is logged in. If they are, they'll be redirected to the `root_path`. This will be useful on pages an authenticated user should not be able to access, such as the login page.
>   - The `current_user` method returns a `User` and sets it as the user on the `Current` class we created. We use [memoization](https://www.honeybadger.io/blog/ruby-rails-memoization/) to avoid fetching the User each time we call the method. We call the `before_action` [filter](https://guides.rubyonrails.org/action_controller_overview.html#filters) so that we have access to the current user before each request. We also add this as a [helper_method](https://api.rubyonrails.org/classes/AbstractController/Helpers/ClassMethods.html#method-i-helper_method) so that we have access to `current_user` in the views.
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
        redirect_to new_confirmation_path, alert: "Incorrect email or password."
      elsif @user.authenticate(params[:user][:password])
        login @user
        redirect_to root_path, notice: "Signed in."
      else
        flash.now[:alert] = "Incorrect email or password."
        render :new, status: :unprocessable_entity
      end
    else
      flash.now[:alert] = "Incorrect email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    logout
    redirect_to root_path, notice: "Signed out."
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

3. Add sign-in form.

```html+ruby
<!-- app/views/sessions/new.html.erb -->
<%= form_with url: login_path, scope: :user do |form| %>
  <div>
    <%= form.label :email %>
    <%= form.email_field :email, required: true %>
  </div>
  <div>
    <%= form.label :password %>
    <%= form.password_field :password, required: true %>
  </div>
  <%= form.submit "Sign In" %>
<% end %>
```

> **What's Going On Here?**
>
> - The `create` method simply checks if the user exists and is confirmed. If they are, then we check their password. If the password is correct, we log them in via the `login` method we created in the `Authentication` Concern. Otherwise, we render an alert.
>   - We're able to call `user.authenticate` because of [has_secure_password](https://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html#method-i-has_secure_password)
>   - Note that we call `downcase` on the email to account for case sensitivity when searching.
>   - Note that we set the flash to "Incorrect email or password." if the user is unconfirmed. This prevents leaking email addresses.
> - The `destroy` method simply calls the `logout` method we created in the `Authentication` Concern.
> - The login form is passed a `scope: :user` option so that the params are namespaced as `params[:user][:some_value]`. This is not required, but it helps keep things organized.

## Step 8: Update Existing Controllers

1. Update Controllers to prevent authenticated users from accessing pages intended for anonymous users.

```ruby
# app/controllers/confirmations_controller.rb
class ConfirmationsController < ApplicationController
  before_action :redirect_if_authenticated, only: [:create, :new]

  def edit
    ...
    if @user.present?
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

## Step 9: Add Password Reset Functionality

1. Update User Model.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  ...
  PASSWORD_RESET_TOKEN_EXPIRATION = 10.minutes
  ...
  def generate_password_reset_token
    signed_id expires_in: PASSWORD_RESET_TOKEN_EXPIRATION, purpose: :reset_password
  end
  ...
  def send_password_reset_email!
    password_reset_token = generate_password_reset_token
    UserMailer.password_reset(self, password_reset_token).deliver_now
  end
  ...
end
```

2. Update User Mailer.

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  ...
  def password_reset(user, password_reset_token)
    @user = user
    @password_reset_token = password_reset_token

    mail to: @user.email, subject: "Password Reset Instructions"
  end
end
```

```html+erb
<!-- app/views/user_mailer/password_reset.html.erb -->
<h1>Password Reset Instructions</h1>

<%= link_to "Click here to reset your password.", edit_password_url(@password_reset_token) %>
```

```text
<!-- app/views/user_mailer/password_reset.text.erb -->
Password Reset Instructions

<%= edit_password_url(@password_reset_token) %>
```

> **What's Going On Here?**
>
> - The `generate_password_reset_token` method creates a [signed_id](https://api.rubyonrails.org/classes/ActiveRecord/SignedId.html#method-i-signed_id) that will be used to securely identify the user. For added security, we ensure that this ID will expire in 10 minutes (this can be controlled with the `PASSWORD_RESET_TOKEN_EXPIRATION` constant) and give it an explicit purpose of `:reset_password`.
> - The `send_password_reset_email!` method will create a new `password_reset_token`. This is to ensure password reset links expire and cannot be reused. It will also send the password reset email to the user.

## Step 10: Build Password Reset Forms

1. Create Passwords Controller.

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
    @user = User.find_signed(params[:password_reset_token], purpose: :reset_password)
    if @user.present? && @user.unconfirmed?
      redirect_to new_confirmation_path, alert: "You must confirm your email before you can sign in."
    elsif @user.nil?
      redirect_to new_password_path, alert: "Invalid or expired token."
    end
  end

  def new
  end

  def update
    @user = User.find_signed(params[:password_reset_token], purpose: :reset_password)
    if @user
      if @user.unconfirmed?
        redirect_to new_confirmation_path, alert: "You must confirm your email before you can sign in."
      elsif @user.update(password_params)
        redirect_to login_path, notice: "Sign in."
      else
        flash.now[:alert] = @user.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    else
      flash.now[:alert] = "Invalid or expired token."
      render :new, status: :unprocessable_entity
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
>   - You'll remember that the `password_reset_token` is a [signed_id](https://api.rubyonrails.org/classes/ActiveRecord/SignedId.html#method-i-signed_id), and is set to expire in 10 minutes. You'll also note that we need to pass the method `purpose: :reset_password` to be consistent with the purpose that was set in the `generate_password_reset_token` method. 
>   - Note that we return `Invalid or expired token.` if the user is not found. This makes it difficult for a bad actor to use the reset form to see which email accounts exist on the application.
> - The `edit` action simply renders the form for the user to update their password. It attempts to find a user by their `password_reset_token`. You can think of the `password_reset_token` as a way to identify the user much like how we normally identify records by their ID. However, the `password_reset_token` is randomly generated and will expire so it's more secure.
> - The `new` action simply renders a form for the user to put their email address in to receive the password reset email.
> - The `update` also ensures the user is identified by their `password_reset_token`. It's not enough to just do this on the `edit` action since a bad actor could make a `PUT` request to the server and bypass the form.
>   - If the user exists and is confirmed we update their password to the one they will set in the form. Otherwise, we handle each failure case differently.

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
> -  We add `param: :password_reset_token` as a [named route parameter](https://guides.rubyonrails.org/routing.html#overriding-named-route-parameters) so that we can identify users by their `password_reset_token` and not `id`. This is similar to what we did with the confirmations routes and ensures a user cannot be identified by their ID.

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
<%= form_with url: password_path(params[:password_reset_token]), scope: :user, method: :put do |form| %>
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

1. Create and run migration.

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
  validates :unconfirmed_email, format: {with: URI::MailTo::EMAIL_REGEXP, allow_blank: true}

  def confirm!
    if unconfirmed_or_reconfirming?
      if unconfirmed_email.present?
        return false unless update(email: unconfirmed_email, unconfirmed_email: nil)
      end
      update_columns(confirmed_at: Time.current)
    else
      false
    end
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
    self.unconfirmed_email = unconfirmed_email.downcase
  end

end
```

> **What's Going On Here?**
>
> - We add a `unconfirmed_email` column to the `users` table so that we have a place to store the email a user is trying to use after their account has been confirmed with their original email.
> - We add `attr_accessor :current_password` so that we'll be able to use `f.password_field :current_password` in the user form (which doesn't exist yet). This will allow us to require the user to submit their current password before they can update their account.
> - We ensure to format the `unconfirmed_email` before saving it to the database. This ensures all data is saved consistently.
> - We add validations to the `unconfirmed_email` column ensuring it's a valid email address.
> - We update the `confirm!` method to set the `email` column to the value of the `unconfirmed_email` column, and then clear out the `unconfirmed_email` column. This will only happen if a user is trying to confirm a new email address. Note that we return `false` if updating the email address fails. This could happen if a user tries to confirm an email address that has already been confirmed. 
> - We add the `confirmable_email` method so that we can call the correct email in the updated `UserMailer`.
> - We add `reconfirming?` and `unconfirmed_or_reconfirming?` to help us determine what state a user is in. This will come in handy later in our controllers.

3. Update User Mailer.

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer

  def confirmation(user, confirmation_token)
    ...
    mail to: @user.confirmable_email, subject: "Confirmation Instructions"
  end
end
```

3. Update Confirmations Controller.

```ruby
# app/controllers/confirmations_controller.rb
class ConfirmationsController < ApplicationController
  ...
  def edit
    ...
    if @user.present?
      if @user.confirm!
        login @user
        redirect_to root_path, notice: "Your account has been confirmed."
      else
        redirect_to new_confirmation_path, alert: "Something went wrong."
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
> - We update the `edit` method to account for the return value of `@user.confirm!`. If for some reason `@user.confirm!` returns `false` (which would most likely happen if the email has already been taken) then we render a generic error. This prevents leaking email addresses.

## Step 12: Update Users Controller

1. Update Authentication Concern.

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
> - We call `authenticate_user!` before editing, destroying, or updating a user since only an authenticated user should be able to do this.
> - We update the `create` method to accept `create_user_params` (formerly `user_params`). This is because we're going to require different parameters for creating an account vs. editing an account.
> - The `destroy` action simply deletes the user and logs them out. Note that we're calling `current_user`, so this action can only be scoped to the user who is logged in.
> - The `edit` action simply assigns `@user` to the `current_user` so that we have access to the user in the edit form.
> - The `update` action first checks if their password is correct. Note that we're passing this in as `current_password` and not `password`. This is because we still want a user to be able to change their password and therefore we need another parameter to store this value. This is also why we have a private `update_user_params` method.
>   - If the user is updating their email address (via `unconfirmed_email`) we send a confirmation email to that new email address before setting it as the `email` value.
>   - We force a user to always put in their `current_password` as an extra security measure in case someone leaves their browser open on a public computer.

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

4. Create an edit form.

```html+ruby
<!-- app/views/users/edit.html.erb -->
<%= form_with model: @user, url: account_path, method: :put do |form| %>
  <%= render partial: "shared/form_errors", locals: { object: form.object } %>
  <div>
    <%= form.label :email, "Current Email" %>
    <%= form.email_field :email, disabled: true %>
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
  <%= form.submit "Update Account" %>
<% end %>
```

> **What's Going On Here?**
>
> - We `disable` the `email` field to ensure we're not passing that value back to the controller. This is just so the user can see what their current email is.
> - We `require` the `current_password` field since we'll always want a user to confirm their password before making changes.
> - The `password` and `password_confirmation` fields are there if a user wants to update their current password.

## Step 13: Update Confirmations Controller

1. Update edit action.

```ruby
# app/controllers/confirmations_controller.rb
class ConfirmationsController < ApplicationController
  ...
  def edit
    ...
    if @user.present? && @user.unconfirmed_or_reconfirming?
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

4. Update the User model.

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
> - We call [has_secure_token](https://api.rubyonrails.org/classes/ActiveRecord/SecureToken/ClassMethods.html#method-i-has_secure_token) on the `remember_token`. This ensures that the value for this column will be set when the record is created. This value will be used later to securely identify the user.

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
    Current.user ||= if session[:current_user_id].present?
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
> - The `remember` method first regenerates a new `remember_token` to ensure these values are being rotated and can't be used more than once. We get the `regenerate_remember_token` method from [has_secure_token](https://api.rubyonrails.org/classes/ActiveRecord/SecureToken/ClassMethods.html#method-i-has_secure_token). Next, we assign this value to a [cookie](https://api.rubyonrails.org/classes/ActionDispatch/Cookies.html). The call to [permanent](https://api.rubyonrails.org/classes/ActionDispatch/Cookies/ChainedCookieJars.html#method-i-permanent) ensures the cookie won't expire until 20 years from now. The call to [encrypted](https://api.rubyonrails.org/classes/ActionDispatch/Cookies/ChainedCookieJars.html#method-i-encrypted) ensures the value will be encrypted. This is vital since this value is used to identify the user and is being set in the browser.
> - The `forget` method deletes the cookie and regenerates a new `remember_token` to ensure these values are being rotated and can't be used more than once.
> - We update the `current_user` method by adding a conditional to first try and find the user by the session, and then fallback to finding the user by the cookie. This is the logic that allows a user to completely exit their browser and remain logged in when they return to the website since the cookie will still be set.

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

2. Add the "Remember me" checkbox to the login form.

```html+ruby
<!-- app/views/sessions/new.html.erb -->
<%= form_with url: login_path, scope: :user do |form| %>
  ...
  <div>
    <%= form.label :remember_me %>
    <%= form.check_box :remember_me %>
  </div>
  <%= form.submit "Sign In" %>
<% end %>
```

## Step 17: Add Friendly Redirects

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
  private
  ...
  def store_location
    session[:user_return_to] = request.original_url if request.get? && request.local?
  end

end
```

> **What's Going On Here?**
>
> - The `store_location` method stores the [request.original_url](https://api.rubyonrails.org/classes/ActionDispatch/Request.html#method-i-original_url) in the [session](https://guides.rubyonrails.org/action_controller_overview.html#session) so it can be retrieved later. We only do this if the request made was a `get` request. We also call `request.local?` to ensure it was a local request. This prevents redirecting to an external application.
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

## Step 17: Account for Timing Attacks

1. Update the User model.

**[Note that this class method will be available in Rails 7.1](https://edgeapi.rubyonrails.org/classes/ActiveRecord/SecurePassword/ClassMethods.html#method-i-authenticate_by)**

```ruby
# app/models/user.rb
class User < ApplicationRecord
  ...
  def self.authenticate_by(attributes)
    passwords, identifiers = attributes.to_h.partition do |name, value|
      !has_attribute?(name) && has_attribute?("#{name}_digest")
    end.map(&:to_h)

    raise ArgumentError, "One or more password arguments are required" if passwords.empty?
    raise ArgumentError, "One or more finder arguments are required" if identifiers.empty?
    if (record = find_by(identifiers))
      record if passwords.count { |name, value| record.public_send(:"authenticate_#{name}", value) } == passwords.size
    else
      new(passwords)
      nil
    end
  end  
  ...
end
```

> **What's Going On Here?**
>
> - This class method serves to find a user using the non-password attributes (such as email), and then authenticates that record using the password attributes. Regardless of whether a user is found or authentication succeeds, `authenticate_by` will take the same amount of time. This prevents [timing-based enumeration attacks](https://en.wikipedia.org/wiki/Timing_attack), wherein an attacker can determine if a password record exists even without knowing the password.

2. Update the Sessions Controller.

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  ...
  def create
    @user = User.authenticate_by(email: params[:user][:email].downcase, password: params[:user][:password])
    if @user
      if @user.unconfirmed?
        redirect_to new_confirmation_path, alert: "Incorrect email or password."
      else
        after_login_path = session[:user_return_to] || root_path
        login @user
        remember(@user) if params[:user][:remember_me] == "1"
        redirect_to after_login_path, notice: "Signed in."
      end
    else
      flash.now[:alert] = "Incorrect email or password."
      render :new, status: :unprocessable_entity
    end
  end
  ...
end
```

> **What's Going On Here?**
>
> - We refactor the `create` method to always start by finding and authenticating the user. Not only does this prevent timing attacks, but it also prevents accidentally leaking email addresses. This is because we were originally checking if a user was confirmed before authenticating them. That means a bad actor could try and sign in with an email address to see if it exists on the system without needing to know the password.

## Step 18: Store Session in the Database

We're currently setting the user's ID in the session. Even though that value is encrypted, the encrypted value doesn't change since it's based on the user id which doesn't change. This means that if a bad actor were to get a copy of the session they would have access to a victim's account in perpetuity. One solution is to [rotate encrypted and signed cookie configurations](https://guides.rubyonrails.org/security.html#rotating-encrypted-and-signed-cookies-configurations). Another option is to configure the [Rails session store](https://guides.rubyonrails.org/configuring.html#config-session-store) to use `mem_cache_store` to store session data. 

The solution we will implement is to set a rotating value to identify the user and store that value in the database.

1. Generate ActiveSession model.

```bash
rails g model active_session user:references
```

2. Update the migration.

```ruby
class CreateActiveSessions < ActiveRecord::Migration[6.1]
  def change
    create_table :active_sessions do |t|
      t.references :user, null: false, foreign_key: {on_delete: :cascade}

      t.timestamps
    end
  end
end
```

> **What's Going On Here?**
>
> - We update the `foreign_key` option from `true` to `{on_delete: :cascade}`. The [on_delete](https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/SchemaStatements.html#method-i-add_foreign_key-label-Creating+a+cascading+foreign+key) option will delete any `active_session` record if its associated `user` is deleted from the database.

3. Run migration.

```bash
rails db:migrate
```

4. Update User model.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  ...
  has_many :active_sessions, dependent: :destroy
  ...
end
```

5. Update Authentication Concern

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  ...
  def login(user)
    reset_session
    active_session = user.active_sessions.create!
    session[:current_active_session_id] = active_session.id
  end
  ...
  def logout
    active_session = ActiveSession.find_by(id: session[:current_active_session_id])
    reset_session
    active_session.destroy! if active_session.present?
  end
  ...
  private

  def current_user
    Current.user = if session[:current_active_session_id].present?
      ActiveSession.find_by(id: session[:current_active_session_id]).user
    elsif cookies.permanent.encrypted[:remember_token].present?
      User.find_by(remember_token: cookies.permanent.encrypted[:remember_token])
    end
  end
  ...
end
```

> **What's Going On Here?**
>
> - We update the `login` method by creating a new `active_session` record and then storing it's ID in the `session`. Note that we replaced `session[:current_user_id]` with `session[:current_active_session_id]`.
> - We update the `logout` method by first finding the `active_session` record from the `session`. After we call `reset_session` we then delete the `active_session` record if it exists. We need to check if it exists because in a future section we will allow a user to log out all current active sessions.
> - We update the `current_user` method by finding the `active_session` record from the `session`, and then returning its associated `user`. Note that we've replaced all instances of `session[:current_user_id]` with `session[:current_active_session_id]`.

6. Force SSL.

```ruby
# config/environments/production.rb
Rails.application.configure do
  ...
  config.force_ssl = true
end
```

> **What's Going On Here?**
>
> - We force SSL in production to prevent [session hijacking](https://guides.rubyonrails.org/security.html#session-hijacking). Even though the session is encrypted we want to prevent the cookie from being exposed through an insecure network. If it were exposed, a bad actor could sign in as the victim.

## Step 19: Capture Request Details for Each New Session

1. Add new columns to the active_sessions table.

```bash
rails g migration add_request_columns_to_active_sessions user_agent:string ip_address:string
rails db:migrate
```

2. Update login method to capture request details.

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  ...
  def login(user)
    reset_session
    active_session = user.active_sessions.create!(user_agent: request.user_agent, ip_address: request.ip)
    session[:current_active_session_id] = active_session.id
  end
  ...
end
```

> **What's Going On Here?**
>
> - We add columns to the `active_sessions` table to store data about when and where these sessions are being created. We are able to do this by tapping into the [request object](https://api.rubyonrails.org/classes/ActionDispatch/Request.html) and returning the [ip](https://api.rubyonrails.org/classes/ActionDispatch/Request.html#method-i-ip) and user agent. The user agent is simply the browser and device.
 

4. Update Users Controller.

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController
  ...
  def edit
    @user = current_user
    @active_sessions = @user.active_sessions.order(created_at: :desc)
  end
  ...
  def update
    @user = current_user
    @active_sessions = @user.active_sessions.order(created_at: :desc)
    ...
  end
end
```

5. Create active session partial.

```html+ruby
<!-- app/views/active_sessions/_active_session.html.erb -->
<tr>
  <td><%= active_session.user_agent %></td>
  <td><%= active_session.ip_address %></td>
  <td><%= active_session.created_at %></td>
</tr>
```

6. Update account page.

```html+ruby
<!-- app/views/users/edit.html.erb -->
...
<h2>Current Logins</h2>
<% if @active_sessions.any? %>
  <table>
    <thead>
      <tr>
        <th>User Agent</th>
        <th>IP Address</th>
        <th>Signed In At</th>
      </tr>
    </thead>
    <tbody>
      <%= render @active_sessions %>
    </tbody>
  </table>
<% end %>
```

> **What's Going On Here?**
>
> - We're simply showing any `active_session` associated with the `current_user`. By rendering the `user_agent`, `ip_address`, and `created_at` values we're giving the `current_user` all the information they need to know if there's any suspicious activity happening with their account. For example, if there's an `active_session` with a unfamiliar IP address or browser, this could indicate that the user's account has been compromised.
> - Note that we also instantiate `@active_sessions` in the `update` method. This is because the `update` method renders the `edit` method during failure cases.

## Step 20: Allow User to Sign Out Specific Active Sessions

1. Generate the Active Sessions Controller and update routes.

```
rails g controller active_sessions
```

```ruby
# app/controllers/active_sessions_controller.rb
class ActiveSessionsController < ApplicationController
  before_action :authenticate_user!

  def destroy
    @active_session = current_user.active_sessions.find(params[:id])

    @active_session.destroy

    if current_user
      redirect_to account_path, notice: "Session deleted."
    else
      reset_session
      redirect_to root_path, notice: "Signed out."
    end
  end

  def destroy_all
    current_user.active_sessions.destroy_all
    reset_session

    redirect_to root_path, notice: "Signed out."
  end
end
```

```ruby
# config/routes.rb
Rails.application.routes.draw do
  ...
  resources :active_sessions, only: [:destroy] do
    collection do
      delete "destroy_all"
    end
  end
end
```

> **What's Going On Here?**
>
> - We ensure only users who are logged in can access these endpoints by calling `before_action :authenticate_user!`.
> - The `destroy` method simply looks for an `active_session` associated with the `current_user`. This ensures that a user can only delete sessions associated with their account.
>   - Once we destroy the `active_session` we then redirect back to the account page or to the homepage. This is because a user may not be deleting a session for the device or browser they're currently logged into. Note that we only call [reset_session](https://api.rubyonrails.org/classes/ActionDispatch/Request.html#method-i-reset_session) if the user has deleted a session for the device or browser they're currently logged into, as this is the same as logging out.
> - The `destroy_all` method is a [collection route](https://guides.rubyonrails.org/routing.html#adding-collection-routes) that will destroy all `active_session` records associated with the `current_user`. Note that we call `reset_session` because we will be logging out the `current_user` during this request.

2. Update views by adding buttons to destroy sessions. 

```html+ruby
<!-- app/views/users/edit.html.erb -->
...
<h2>Current Logins</h2>
<% if @active_sessions.any? %> 
  <%= button_to "Log out of all other sessions", destroy_all_active_sessions_path, method: :delete %>
  <table>
    <thead>
      <tr>
        <th>User Agent</th>
        <th>IP Address</th>
        <th>Signed In At</th>
        <th>Sign Out</th>
      </tr>
    </thead>
    <tbody>
      <%= render @active_sessions %>
    </tbody>
  </table>
<% end %>
```

```html+ruby
<!-- app/views/active_sessions/_active_session.html.erb -->
<tr>
  <td><%= active_session.user_agent %></td>
  <td><%= active_session.ip_address %></td>
  <td><%= active_session.created_at %></td>
  <td><%= button_to "Sign Out", active_session_path(active_session), method: :delete %></td>
</tr>
```

3. Update Authentication Concern.

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  ...
  private

  def current_user
    Current.user = if session[:current_active_session_id].present?
      ActiveSession.find_by(id: session[:current_active_session_id])&.user
    elsif cookies.permanent.encrypted[:remember_token].present?
      User.find_by(remember_token: cookies.permanent.encrypted[:remember_token])
    end
  end
  ...
end
```

> **What's Going On Here?**
>
> - This is a very subtle change, but we've added a [safe navigation operator](https://ruby-doc.org/core-2.6/doc/syntax/calling_methods_rdoc.html#label-Safe+navigation+operator) via the `&.user` call. This is because `ActiveSession.find_by(id: session[:current_active_session_id])` can now return `nil` since we're able to delete other `active_session` records.

## Step 21: Refactor Remember Logic

Since we're now associating our sessions with an `active_session` and not a `user`, we'll want to remove the `remember_token` token from the `users` table and onto the `active_sessions`.

1. Move remember_token column from users to active_sessions table.

```bash
rails g migration move_remember_token_from_users_to_active_sessions
```

```ruby
# db/migrate/[timestamp]_move_remember_token_from_users_to_active_sessions.rb
class MoveRememberTokenFromUsersToActiveSessions < ActiveRecord::Migration[6.1]
  def change
    remove_column :users, :remember_token
    add_column :active_sessions, :remember_token, :string, null: false

    add_index :active_sessions, :remember_token, unique: true
  end
end
```

2. Run migration.

```bash
rails db:migrate
```

> **What's Going On Here?**
>
> - We add `null: false` to ensure this column always has a value.
> - We add a [unique index](https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/Table.html#method-i-index) to ensure this column has unique data.

3. Update User Model.

```diff
 class User < ApplicationRecord
    ...
-   has_secure_token :remember_token
    ...
 end
```

4. Update Active Session Model.

```ruby
# app/models/active_session.rb
class ActiveSession < ApplicationRecord
  ...
  has_secure_token :remember_token
end
```

> **What's Going On Here?**
>
> - We call [has_secure_token](https://api.rubyonrails.org/classes/ActiveRecord/SecureToken/ClassMethods.html#method-i-has_secure_token) on the `remember_token`. This ensures that the value for this column will be set when the record is created. This value will be used later to securely identify the user.
> - Note that we remove this from the `user` model.

5. Refactor the Authentication Concern.

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  ...
  def login(user)
    reset_session
    active_session = user.active_sessions.create!(user_agent: request.user_agent, ip_address: request.ip)
    session[:current_active_session_id] = active_session.id

    active_session
  end

  def forget_active_session
    cookies.delete :remember_token
  end
  ...
  def remember(active_session)
    cookies.permanent.encrypted[:remember_token] = active_session.remember_token
  end
  ...
  private

  def current_user
    Current.user = if session[:current_active_session_id].present?
      ActiveSession.find_by(id: session[:current_active_session_id])&.user
    elsif cookies.permanent.encrypted[:remember_token].present?
      ActiveSession.find_by(remember_token: cookies.permanent.encrypted[:remember_token])&.user
    end
  end
  ...
end
```

> **What's Going On Here?**
> 
> - The `login` method now returns the `active_session`. This will be used later when calling `SessionsController#create`.
> - The `forget` method has been renamed to `forget_active_session` and no longer takes any arguments. This method simply deletes the `cookie`. We don't need to call `active_session.regenerate_remember_token` since the `active_session` will be deleted, and therefor cannot be referenced again.
> - The `remember` method now accepts an `active_session` and not a `user`. We do not need to call `active_session.regenerate_remember_token` since a new `active_session` record will be created each time a user logs in. Note that we now save `active_session.remember_token` to the cookie.
> - The `current_user` method now finds the `active_session` record if the `remember_token` is present and returns the user via the [safe navigation operator](https://ruby-doc.org/core-2.6/doc/syntax/calling_methods_rdoc.html#label-Safe+navigation+operator).

6. Refactor the Sessions Controller.

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  def create
    ...
    if @user
      if @user.unconfirmed?
        ...
      else
        ...
        active_session = login @user
        remember(active_session) if params[:user][:remember_me] == "1"
      end
    else
    ...
    end
  end

   def destroy
    forget_active_session
    ...
  end
end
```

> **What's Going On Here?**
> 
> - Since the `login` method now returns an `active_session`, we can take that value and pass it to `remember`.
> - We replace `forget(current_user)` with `forget_active_session` to reflect changes to the method name and structure.

7. Refactor Active Sessions Controller

```ruby
# app/controllers/active_sessions_controller.rb
class ActiveSessionsController < ApplicationController
  ...
  def destroy
    ...
    if current_user
    ...
    else
      forget_active_session
      ...
    end
  end

  def destroy_all
    forget_active_session
    current_user.active_sessions.destroy_all
    ...
  end
end
```