# frozen_string_literal: true

class ProcessedFact < ApplicationRecord
  validates :handler, presence: true
  validates :event_id, presence: true
end
