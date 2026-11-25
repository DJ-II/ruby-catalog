namespace :admin do
  desc 'Grant admin to an already registered user: bin/rails admin:grant EMAIL=user@example.com'
  task grant: :environment do
    email = ENV.fetch('EMAIL').strip.downcase
    user = User.find_by!(email: email)
    user.update!(admin: true)
    puts "Granted admin to #{user.username}"
  end
end
