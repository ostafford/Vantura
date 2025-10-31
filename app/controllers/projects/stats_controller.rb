module Projects
  class StatsController < ApplicationController
    before_action :set_project
    before_action :authorize_member!

    # GET /projects/:id/stats/bars
    # Params:
    # - period: "month" (default) | "year"
    # - year: Integer (defaults to current year)
    # - month: Integer 1..12 (base month for 12-month window when period=month)
    # - group_by: "none" (default) | "category" | "merchant" | "contributor"
    # - ids[]: optional list of exact names/ids to include when grouping (e.g., merchants/categories or user ids for contributors)
    def bars
      period = params[:period].presence_in(%w[month year]) || "month"
      year = params[:year].to_i.nonzero? || Date.today.year
      month = params[:month].to_i.between?(1, 12) ? params[:month].to_i : Date.today.month
      group_by = params[:group_by].presence_in(%w[none category merchant contributor]) || "none"
      ids = Array(params[:ids]).first(12) # cap for sanity

      result = ProjectBarsAggregator.call(
        project: @project,
        period: period,
        year: year,
        month: month,
        group_by: group_by,
        ids: ids
      )

      render json: result
    end

    private

    def set_project
      @project = Project.find(params[:id])
    end

    def authorize_member!
      return if @project.owner_id == Current.user.id || @project.members.exists?(id: Current.user.id)
      head :forbidden
    end
  end
end


