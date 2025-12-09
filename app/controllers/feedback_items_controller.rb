class FeedbackItemsController < ApplicationController
  before_action :authenticate_user!

  def create
    @feedback_item = current_user.feedback_items.build(feedback_item_params)
    if @feedback_item.save
      redirect_to request.referer || root_path, notice: I18n.t("flash.feedback.submitted")
    else
      redirect_to request.referer || root_path, alert: I18n.t("flash.feedback.failed")
    end
  end

  private

  def feedback_item_params
    params.require(:feedback_item).permit(:feedback_type, :description)
  end
end
