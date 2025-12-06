require "rails_helper"

RSpec.describe Session, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "validations" do
    it { should validate_presence_of(:user_id) }
  end

  describe "scopes" do
    describe ".active" do
      it "returns sessions active within the last 2 hours" do
        active_session = create(:session, last_active_at: 1.hour.ago)
        expired_session = create(:session, last_active_at: 3.hours.ago)
        new_session = create(:session, last_active_at: nil)

        active_sessions = Session.active

        expect(active_sessions).to include(active_session)
        expect(active_sessions).to include(new_session)
        expect(active_sessions).not_to include(expired_session)
      end
    end

    describe ".recent" do
      it "returns sessions ordered by created_at descending" do
        old_session = create(:session, created_at: 2.days.ago)
        new_session = create(:session, created_at: 1.hour.ago)

        recent_sessions = Session.recent

        expect(recent_sessions.first).to eq(new_session)
        expect(recent_sessions.last).to eq(old_session)
      end
    end

    describe ".for_user" do
      it "returns sessions for a specific user" do
        user1 = create(:user)
        user2 = create(:user)
        session1 = create(:session, user: user1)
        session2 = create(:session, user: user2)

        user1_sessions = Session.for_user(user1)

        expect(user1_sessions).to include(session1)
        expect(user1_sessions).not_to include(session2)
      end
    end
  end

  describe "#active?" do
    it "returns true for recently active session" do
      session = create(:session, last_active_at: 1.hour.ago)
      expect(session.active?).to be true
    end

    it "returns true for new session (last_active_at is nil)" do
      session = create(:session, last_active_at: nil)
      expect(session.active?).to be true
    end

    it "returns false for expired session" do
      session = create(:session, last_active_at: 3.hours.ago)
      expect(session.active?).to be false
    end
  end

  describe "#update_activity!" do
    it "updates last_active_at to current time" do
      session = create(:session, last_active_at: 3.hours.ago)
      old_time = session.last_active_at

      session.update_activity!

      expect(session.last_active_at).to be > old_time
      expect(session.last_active_at).to be_within(5.seconds).of(Time.current)
    end
  end

  describe "#expired?" do
    it "returns false for active session" do
      session = create(:session, last_active_at: 1.hour.ago)
      expect(session.expired?).to be false
    end

    it "returns true for expired session" do
      session = create(:session, last_active_at: 3.hours.ago)
      expect(session.expired?).to be true
    end
  end
end
