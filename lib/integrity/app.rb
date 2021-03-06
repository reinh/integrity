module Integrity
  class App < Sinatra::Default
    set :root,     File.dirname(__FILE__) + "/../.."
    set :app_file, __FILE__
    enable :sessions

    include Integrity
    include Integrity::Helpers

    not_found do
      status 404
      show :not_found, :title => "lost, are we?"
    end

    error do
      @error = request.env["sinatra.error"]
      status 500
      show :error, :title => "something has gone terribly wrong"
    end

    before do
      # The browser only sends http auth data for requests that are explicitly
      # required to do so. This way we get the real values of +#logged_in?+ and
      # +#current_user+
      login_required if session[:user]
    end

    get "/integrity.css" do
      response["Content-Type"] = "text/css; charset=utf-8"
      etag stylesheet_hash
      sass :integrity
    end

    get "/" do
      @projects = Project.only_public_unless(authorized?)
      show :home, :title => "projects"
    end

    get "/login" do
      login_required

      session[:user] = current_user
      redirect root_url
    end

    get "/new" do
      login_required

      @project = Project.new
      show :new, :title => ["projects", "new project"]
    end

    post "/" do
      login_required

      @project = Project.new(params[:project_data])

      if @project.save
        update_notifiers_of(@project)
        redirect project_url(@project)
      else
        show :new, :title => ["projects", "new project"]
      end
    end

    get "/:project.atom" do
      login_required unless current_project.public?
      response["Content-Type"] = "application/rss+xml; charset=utf-8"
      builder :project
    end

    get "/:project" do
      login_required unless current_project.public?
      show :project, :title => ["projects", current_project.name]
    end

    put "/:project" do
      login_required

      if current_project.update_attributes(params[:project_data])
        update_notifiers_of(current_project)
        redirect project_url(current_project)
      else
        show :new, :title => ["projects", current_project.permalink, "edit"]
      end
    end

    delete "/:project" do
      login_required

      current_project.destroy
      redirect root_url
    end

    get "/:project/edit" do
      login_required

      show :new, :title => ["projects", current_project.permalink, "edit"]
    end

    post "/:project/push" do
      login_required

      content_type "text/plain"

      begin
        current_project.push(params[:payload])
        201
      rescue ArgumentError
        [422, "Invalid Request"]
      end
    end

    post "/:project/builds" do
      login_required

      current_project.build
      redirect project_url(current_project)
    end

    get "/:project/commits/:commit" do
      login_required unless current_project.public?

      show :build, :title => ["projects", current_project.permalink, current_commit.short_commit_identifier]
    end

    get "/:project/builds/:commit" do
      redirect "/#{params[:project]}/commits/#{params[:commit]}", 301
    end

    post "/:project/commits/:commit/builds" do
      login_required

      current_project.build(params[:commit])
      redirect commit_url(current_commit)
    end
  end
end
