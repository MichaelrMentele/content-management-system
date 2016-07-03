require "sinatra"

require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

require "redcarpet"
require "yaml"

require "bcrypt"

configure do 
  enable :sessions
  set :erb, :escape_html => true
  set :session_secret, "secret"
end

###########
# Methods #
###########

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def filenames
  pattern = File.join(data_path, "*")
  Dir.glob(pattern).map do |path|
    File.basename(path)
  end
end

def load_file_content(file_path)
  content = File.read(file_path)

  case File.extname(file_path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    render_markdown(content)
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/user_accounts.yml", __FILE__)
  else
    File.expand_path("../user_accounts.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def has_ext?(file_path)
  File.extname(file_path).size != 0
end

def render_markdown(content)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(content)
end

def check_user_credentials
  unless logged_in?
    session[:error] = "You must be signed in to do that!"
    redirect "/"
  end
end

def logged_in?
  !!session[:user]
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    hashed_password = BCrypt::Password.new(credentials[username])
    hashed_password == password
  else
    false
  end
end

#######
# GET #
#######

# Display an index of content files
get "/" do 
  @files = filenames
  erb :index
end

# Displays the contents of a file
get "/:file" do 
  @filename = params[:file]
  @file_path = File.join(data_path, @filename)

  if File.exists?(@file_path)
    load_file_content(@file_path)
  else
    session[:error] = "#{@filename} does not exist."
    redirect "/"
  end
end

get "/edit/:file" do
  check_user_credentials

  @filename = params[:file]
  @file_path = File.join(data_path, @filename)

  @content = File.readlines(@file_path)

  erb :edit_file
end

get "/file/new" do 
  check_user_credentials

  erb :new_document
end

get "/users/signin" do 
  erb :signin
end

########
# POST #
########

post "/file/new" do 
  check_user_credentials

  @filename = params[:new_document].to_s
  @file_path = File.join(data_path, @filename)
  
  if @filename.size == 0
    session[:error] = "New Document must have a name!"
    status 422
    erb :new_document
  elsif !has_ext?(@file_path)
    session[:error] = "File must have an extension!"
    erb :new_document
  else
    File.new(@file_path, "w")
    session[:success] = "#{@filename} was created"
    redirect "/"
  end
end

post "/edit/:file" do
  check_user_credentials

  @filename = params[:file]
  @file_path = File.join(data_path, @filename)

  @content = params[:new_content]
  File.write(@file_path, @content)

  session[:success] = "#{@filename} was updated."

  redirect "/"
end

post "/delete/:file" do
  check_user_credentials

  filename = params[:file]
  file_path = File.join(data_path, filename)
  File.delete(file_path)

  session[:success] = "#{filename} was deleted!"
  redirect "/"
end

post "/users/signin" do 
  user = params[:username]
  password = params[:password]

  if valid_credentials?(user, password)
    session[:user] = user
    session[:success] = "Welcome #{user}!"
    redirect "/"
  else
    session[:error] = "Invalid Signin"
    status 422
    erb :signin
  end
end

post "/users/signout" do 
  session[:success] = "#{session[:user]} has signed out."
  session.delete(:user)
  redirect "/"
end

###########
# Helpers #
###########

helpers do 
  def remove_extension(file)
    File.basename(file, File.extname(file))
  end
end
