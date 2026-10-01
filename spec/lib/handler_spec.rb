require "rails_helper"

RSpec.describe Handler, :isolated_event_store do
  let(:event_store) { Rails.configuration.event_store }
  let(:command_bus) { Rails.configuration.command_bus }

  before do
    stub_const("Spec::Recorded", Class.new(Fact) do
      def stream_names
        [ "Recorded$#{data.fetch(:tid)}" ]
      end
    end)
    Spec::Recorded.const_set(:SCHEMA, { tid: String }.freeze)

    stub_const("Spec::Recorder", Class.new do
      include Handler.async(queue: "low")
      subscribes_to Spec::Recorded

      cattr_accessor :seen, default: []
      cattr_accessor :correlations, default: []
      cattr_accessor :causations, default: []

      def call(fact)
        self.class.seen << fact.data.fetch(:tid)
        current = event_store.metadata
        self.class.correlations << current[:correlation_id]
        self.class.causations << current[:causation_id]
      end
    end)

    Spec::Recorder.seen = []
    Spec::Recorder.correlations = []
    Spec::Recorder.causations = []

    stub_const("Spec::Record", Class.new do
      include Command::Executable

      attribute :tid, String
      validates :tid, presence: true

      def call
        event_store.publish(Spec::Recorded.strict(data: { tid: tid }))
      end
    end)

    event_store.subscribe(Spec::Recorder::Job, to: [ Spec::Recorded ])
  end

  it "generates a named ActiveJob companion on the given queue" do
    expect(Spec::Recorder::Job.queue_name).to eq("low")
    expect(Spec::Recorder::Job.ancestors).to include(RailsEventStore::CorrelatedHandler)
  end

  it "exposes its subscriptions keyed by fact" do
    expect(Spec::Recorder.subscriptions).to eq(Spec::Recorded => [ Spec::Recorder::Job ])
  end

  it "does not run the handler inline when the fact is published" do
    command_bus.call(Spec::Record.new(tid: "async-1"))

    expect(Spec::Recorder.seen).to be_empty
  end

  it "runs the handler once the queue is drained" do
    perform_enqueued_jobs do
      command_bus.call(Spec::Record.new(tid: "async-2"))
    end

    expect(Spec::Recorder.seen).to eq([ "async-2" ])
  end

  it "carries the correlation id into the handler and sets causation" do
    fact = nil

    perform_enqueued_jobs do
      command_bus.call(Spec::Record.new(tid: "async-3"))
      fact = event_store.read.stream("Recorded$async-3").first
    end

    expect(Spec::Recorder.correlations.first).to eq(fact.metadata[:correlation_id])
    expect(Spec::Recorder.causations.first).to eq(fact.event_id)
  end

  it "requires subclasses to implement #call" do
    stub_const("Spec::Mute", Class.new { include Handler.async })

    expect { Spec::Mute.new.call(nil) }
      .to raise_error(NotImplementedError, /must implement #call/)
  end
end
