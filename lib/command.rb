# frozen_string_literal: true

module Command
  Error = Class.new(StandardError)

  Invalid = Class.new(Error)

  Unhandled = Class.new(Error)

  module Attributes
    extend ActiveSupport::Concern

    CLASS_TO_ACTIVE_MODEL_TYPE = {
      String => :string,
      Integer => :integer,
      Float => :float,
      BigDecimal => :decimal,
      Date => :date,
      Time => :datetime,
      DateTime => :datetime,
      TrueClass => :boolean,
      FalseClass => :boolean
    }.freeze

    module TypeMapping
      def attribute(name, type = nil, **options)
        resolved =
          if type.nil?
            ActiveModel::Type::Value.new
          else
            CLASS_TO_ACTIVE_MODEL_TYPE.fetch(type) { ActiveModel::Type::Value.new }
          end

        super(name, resolved, **options)
      end
    end

    included do
      include ActiveModel::Model
      include ActiveModel::Attributes
      extend TypeMapping
    end
  end

  module Executable
    extend ActiveSupport::Concern

    included do
      include Command::Attributes
      include EventStoreInjector
    end

    def call
      raise NotImplementedError, "#{self.class.name} must implement #call"
    end
  end
end
