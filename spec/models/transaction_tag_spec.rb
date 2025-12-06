require "rails_helper"

RSpec.describe TransactionTag, type: :model do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:transaction) { create(:transaction, user: user, account: account) }
  let(:tag) { create(:tag) }

  describe "associations" do
    it { should belong_to(:transaction_record).class_name("Transaction") }
    it { should belong_to(:tag) }
  end

  describe "validations" do
    subject { build(:transaction_tag, transaction_record: transaction, tag: tag) }

    it { should validate_uniqueness_of(:transaction_id).scoped_to(:tag_id) }
  end

  describe "transaction_record association" do
    it "correctly links to Transaction model" do
      transaction_tag = create(:transaction_tag, transaction_record: transaction, tag: tag)

      expect(transaction_tag.transaction_record).to eq(transaction)
      expect(transaction_tag.transaction_record).to be_a(Transaction)
    end

    it "allows accessing transaction through transaction_record" do
      transaction_tag = create(:transaction_tag, transaction_record: transaction, tag: tag)

      expect(transaction_tag.transaction_record.user).to eq(user)
      expect(transaction_tag.transaction_record.account).to eq(account)
    end
  end

  describe "uniqueness constraint" do
    it "prevents duplicate transaction-tag pairs" do
      create(:transaction_tag, transaction_record: transaction, tag: tag)
      duplicate = build(:transaction_tag, transaction_record: transaction, tag: tag)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:transaction_id]).to be_present
    end

    it "allows same tag for different transactions" do
      transaction2 = create(:transaction, user: user, account: account)
      tag1 = create(:tag)

      create(:transaction_tag, transaction_record: transaction, tag: tag1)
      tag2 = create(:transaction_tag, transaction_record: transaction2, tag: tag1)

      expect(tag2).to be_valid
    end
  end
end
