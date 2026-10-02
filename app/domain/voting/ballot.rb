# frozen_string_literal: true

module Voting
  class Ballot < ApplicationRecord
    self.table_name = "votes"

    validates :event_tid, presence: true
    validates :user_id, presence: true
    validates :direction, inclusion: { in: DIRECTIONS }
    validates :user_id, uniqueness: { scope: :event_tid }

    def up?
      direction == "up"
    end

    def down?
      direction == "down"
    end
  end
end
