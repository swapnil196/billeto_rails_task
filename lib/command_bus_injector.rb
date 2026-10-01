# frozen_string_literal: true

module CommandBusInjector
  extend ActiveSupport::Concern

  class_methods do
    def command_bus
      Rails.configuration.command_bus
    end
  end

  def command_bus
    Rails.configuration.command_bus
  end
end
