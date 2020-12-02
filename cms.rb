#cms.rb
require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require "bcrypt"

configure do 
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

def generate_credentials_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end 

def load_user_credentials
  credentials_path = generate_credentials_path
  YAML.load_file(credentials_path)
end 

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

before do
  pattern = File.join(data_path, "*")
  @contents = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
end

def file_exists?(file_name)
  @contents.include?(file_name)
end

def error_message(file_name)
  if !file_exists?(file_name)
    "#{file_name} does not exist"
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

def valid_credentials?(username, password)
  #params[:username] == "admin" && params[:password] == "secret"
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end 

def extension_valid?(file_path)
  extension = File.extname(file_path)
  valid_extensions = [".txt", ".md"]
  valid_extensions.include?(extension)
end

def redirect_invalid_user
  session[:message] = "You must be signed in to do that"
  redirect "/" unless session[:username] == "admin"
end

def create_copy(file_name)
  file_name_copy = "copy " + file_name
  file_path_copy = File.join(data_path, file_name_copy)
  file_path = File.join(data_path, file_name)
  FileUtils.cp_r(file_path, file_path_copy )
end

def generate_hashed_password(password)
  BCrypt::Password.create(password).to_s
end

def generate_credentials_hash(user_name, password)
  user_credentials = load_user_credentials
  

  if user_credentials.class == Hash
    user_credentials
  else
    credentials_hash = {}
    credentials_hash
  end
end

get "/" do
  erb :index
end

get "/users/login" do
  erb :login
end

post "/users/login" do

  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:error] = "invalid credentials"
    status 422
    erb :login
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out"
  redirect "/"
end

get "/users/signup" do
  erb :sign_up
end

post "/users/signup" do
  user_name = params[:username]
  password = params[:password]
  credentials_hash = generate_credentials_hash(user_name, password)

  credentials_hash[user_name] = generate_hashed_password(password)
  
  File.open(generate_credentials_path, "w") {|file| file.write(credentials_hash.to_yaml) }

  redirect "/users/login"
end

get '/new' do
  redirect_invalid_user
  erb :new_file
end

post '/create' do
  redirect_invalid_user
  filename = params[:new_file_name].to_s
  file_path = File.join(data_path, filename)

  if filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new_file
  elsif !extension_valid?(file_path)
    session[:message] = "Please use a valid exetnesion"
    status 422
    erb :new_file
  else
    File.write(file_path, "default")
    session[:message] = "#{params[:new_file_name]} has been created."

    redirect "/"
  end
end

get '/:file' do
  file_name = params[:file]
  path = File.join(data_path, file_name)

  if error_message(file_name)
    session[:error] =  error_message(file_name)
    redirect "/"
  else
    load_file_content(path)
  end
end


get '/:file/edit' do
  redirect_invalid_user
  @file_name = params[:file]
  path = File.join(data_path, @file_name)
  @content = File.read(path)
  erb :edit_file
end

post '/:file/delete' do
  redirect_invalid_user
  file_name = params[:file]
  path = File.join(data_path, file_name)
  File.delete(path)
  session[:message] = "#{file_name} has been deleted."
  redirect "/"
end

post '/:file/duplicate' do 
  redirect_invalid_user
  file_name = params[:file] #get the file name you want to dup
  create_copy(file_name)
  session[:message] = "#{file_name} has been duplicated"
  redirect "/"
end

post '/:file' do
  redirect_invalid_user
  @file_name = params[:file]
  path = File.join(data_path, @file_name)
  File.write(path, params[:input_text])
  session[:message] = "#{@file_name} has been updated."
  redirect "/"
end

