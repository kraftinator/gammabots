class BotEvent < ApplicationRecord
  belongs_to :bot
  validates :event_type, presence: true
end
