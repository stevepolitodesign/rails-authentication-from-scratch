namespace :post_setup_instructions do
  desc "Prints instructions after running the setup script"
  task perform: :environment do
    puts "\n== Setup complete 🎉  =="
    puts "👉  Run ./bin/dev to start the development server"
    puts "\n== You can login with the following account 🔐 =="
    puts "Email: confirmed_user@example.com"
    puts "Password: password"
  end
end
