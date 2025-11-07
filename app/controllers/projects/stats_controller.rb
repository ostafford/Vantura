module Projects
  class StatsController < ApplicationController
    include ProjectAuthorization

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
      result = ProjectBarsAggregator.call(
        project: @project,
        **stats_params
      )

      render json: result
    end

    private

    def set_project
      @project = Project.find(params[:id])
    end

    def stats_params
      {
        period: params[:period].presence_in(%w[month year]) || "month",
        year: params[:year].to_i.nonzero? || Date.today.year,
        month: params[:month].to_i.between?(1, 12) ? params[:month].to_i : Date.today.month,
        group_by: params[:group_by].presence_in(%w[none category merchant contributor]) || "none",
        ids: Array(params[:ids]).first(12)
      }
    end
  end
end
