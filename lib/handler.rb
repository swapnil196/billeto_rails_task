# frozen_string_literal: true

module Handler
  DEFAULT_QUEUE = "default"

  def self.async(queue: DEFAULT_QUEUE)
    AsyncDefinition.new(queue)
  end

  class AsyncDefinition < Module
    def initialize(queue)
      @queue = queue
      super()

      define_method(:call) do |_fact|
        raise NotImplementedError, "#{self.class.name} must implement #call"
      end
    end

    def included(base)
      base.extend(ClassMethods)
      base.include(EventStoreInjector)
      base.include(CommandBusInjector)
      base.subscribed_facts = []
      base.const_set(:Job, build_job(base, @queue))
    end

    private

    def build_job(handler_class, queue)
      job = Class.new(ApplicationJob)
      job.queue_as(queue)
      job.prepend(RailsEventStore::CorrelatedHandler)
      job.prepend(
        RailsEventStore::AsyncHandler.with(
          event_store_locator: -> { Rails.configuration.event_store },
          serializer: JSON
        )
      )
      job.define_method(:perform) { |fact| handler_class.new.call(fact) }
      job
    end
  end

  module ClassMethods
    def subscribed_facts
      @subscribed_facts ||= []
    end

    attr_writer :subscribed_facts

    def subscribes_to(*fact_classes)
      self.subscribed_facts = subscribed_facts | fact_classes
    end

    def subscriptions
      subscribed_facts.index_with { [ const_get(:Job) ] }
    end
  end
end
