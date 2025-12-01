class CalendarController < ApplicationController
  before_action :authenticate_user!

  def index
    @year = params[:year]&.to_i || Time.current.year
    @month = params[:month]&.to_i || Time.current.month
  end
end
