require 'bundler/setup'
Bundler.require
# Set the database based on the current environment
database_name = 'export-endpoint'
database_user = 'root'
database_password = '161int'
database_host = 'database'
database_port = 5432



# Connect ActiveRecord with the current database
ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  host: database_host,
  port: database_port,
  username: database_user,
  password: database_password,
  database: database_name,
  encoding: 'utf8'
)






# # Set the database based on the current environment
# database_name = 'export-endpoint'
# database_user = 'root'
# database_password = '161int'
# database_url = ENV['DATABASE_URL'] || "postgres://#{database_user}:#{database_password}@localhost/#{database_name}"

# db = URI.parse(database_url)

# # Connect ActiveRecord with the current database
# ActiveRecord::Base.establish_connection(
#   adapter: db.scheme == 'postgres' ? 'postgresql' : db.scheme,
#   host: db.host,
#   port: db.port,
#   username: db.user,
#   password: db.password,
#   database: db.path.gsub('/', ''),
#   encoding: 'utf8'
# )
