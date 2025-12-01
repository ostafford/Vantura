class ProjectsController < ApplicationController
  before_action :authenticate_user!

  def index
    @projects = current_user.projects
                            .includes(:owner, :members)
                            .order(created_at: :desc)
  end

  def show
    @project = current_user.projects.find(params[:id])
  end
end
