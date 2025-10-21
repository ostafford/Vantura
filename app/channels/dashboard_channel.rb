class DashboardChannel < ApplicationCable::Channel
  def subscribed
    # Stream updates specific to this user's dashboard
    stream_for current_user
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    stop_all_streams
  end
end
