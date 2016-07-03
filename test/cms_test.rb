ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CMS_test < Minitest::Test 
  include Rack::Test::Methods

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { user: "admin"} }
  end

  #########
  # Tests #
  #########

  def test_index
    create_document "changes.txt"
    create_document "history.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end

  def test_viewing_text_document
    create_document "about.txt", "This is a CMS."

    get "/about.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "This is a CMS."
  end

  def test_view_nonexistent_document
    get "/thisdoesntexist"

    assert_equal 302, last_response.status

    assert_equal "thisdoesntexist does not exist.", session[:error]
  end

  def test_view_markdown_document
    create_document "info.md", "# Information"
    get "/info.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Information</h1>"
  end

  def test_file_edit
    get "/", {}, admin_session

    create_document "changes.txt"
    get "/edit/changes.txt"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    get "/", {}, admin_session

    post "/edit/changes.txt", new_content: "new content"

    assert_equal 302, last_response.status
    assert_equal "changes.txt was updated.", session[:success]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_new_document
    get "/", {}, admin_session

    get "/file/new"

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<form action="/file/new" method="post">)
    assert_includes last_response.body, %q(button type="submit">Create Document</button>)
  end

  def test_create_new_document
    get "/", {}, admin_session

    post "/file/new", new_document: "test.md"

    assert_equal 302, last_response.status
    assert_equal "test.md was created", session[:success]

    get "/"
    assert_includes last_response.body, "test.md"
  end

  def test_create_empty_document
    get "/", {}, admin_session

    post "/file/new", new_document: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, "New Document must have a name!"
  end

  def test_delete_document
    get "/", {}, admin_session

    create_document "sacrifice.txt"

    post "/delete/sacrifice.txt"

    assert_equal 302, last_response.status
    assert_equal "sacrifice.txt was deleted!", session[:success]

    get "/"
    refute_includes last_response.body, %q(href="/sacrifice.txt")
  end

  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, "username"
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome #{session[:user]}!", session[:success]
    assert_equal "admin", session[:user]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "test", password: "shh"
    assert_equal 422, last_response.status
    assert_equal nil, session[:user]
    assert_includes last_response.body, "Invalid Signin"    
  end

  def test_signout
    get "/", {}, admin_session
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    get last_response["Location"]

    assert_equal nil, session[:user]
    assert_includes last_response.body, "has signed out"
    assert_includes last_response.body, "Signin"
  end

  def test_create_new_document_signed_out
    post "/file/new", new_document: "test.md"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that!", session[:error]
  end

  def test_delete_document_signed_out
    create_document "sacrifice.txt"

    post "/delete/sacrifice.txt"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that!", session[:error]
  end

  def test_updating_document_signed_out
    post "/edit/changes.txt", new_content: "new content"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that!", session[:error]
  end

  def test_file_edit_signed_out
    create_document "changes.txt"

    get "/edit/changes.txt"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that!", session[:error]
  end
  
  def test_new_document_signed_out
    get "/file/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that!", session[:error]
  end
end



