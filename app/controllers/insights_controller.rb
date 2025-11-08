class InsightsController < ApplicationController
  def dismiss
    insight_type = params[:insight_type]

    if insight_type.blank?
      render json: { error: "insight_type is required" }, status: :unprocessable_entity
      return
    end

    Current.user.dismiss_insight_type(insight_type)

    respond_to do |format|
      format.json { render json: { success: true, dismissed_types: Current.user.dismissed_insight_types } }
      format.html { redirect_back(fallback_location: root_path, notice: "Insight dismissed") }
    end
  end

  def undismiss
    insight_type = params[:insight_type]

    if insight_type.blank?
      render json: { error: "insight_type is required" }, status: :unprocessable_entity
      return
    end

    Current.user.undismiss_insight_type(insight_type)

    respond_to do |format|
      format.json { render json: { success: true, dismissed_types: Current.user.dismissed_insight_types } }
      format.html { redirect_back(fallback_location: root_path, notice: "Insight restored") }
    end
  end
end
