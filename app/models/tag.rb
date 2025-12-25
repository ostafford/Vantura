class Tag < ApplicationRecord
  belongs_to :user
  has_many :transaction_tags, dependent: :destroy
  has_many :transactions, through: :transaction_tags

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id }
end

