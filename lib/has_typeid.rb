# frozen_string_literal: true

module HasTypeid
  extend ActiveSupport::Concern

  SEPARATOR = "_"
  RANDOM_LENGTH = 16

  class_methods do
    def has_typeid(prefix)
      @typeid_prefix = prefix.to_s

      before_create :assign_typeid
    end

    def typeid_prefix
      @typeid_prefix
    end

    def generate_typeid
      [ typeid_prefix, SecureRandom.base58(RANDOM_LENGTH) ].join(SEPARATOR)
    end
  end

  def to_param
    tid
  end

  private

  def assign_typeid
    self.tid ||= self.class.generate_typeid
  end
end
