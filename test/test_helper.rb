ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
  def current_user
    session[:current_active_session_id] && ActiveSession.find_by(id: session[:current_active_session_id])&.user
  end

  def login(user, remember_user: nil)
    post login_path, params: {
      user: {
        email: user.email,
        password: user.password,
        remember_me: remember_user == true ? 1 : 0
      }
    }
  end

  def logout
    session.delete(:current_active_session_id)
  end
end
