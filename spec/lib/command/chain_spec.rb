require "rails_helper"

# Exercises the assembled chain rather than the links in isolation: these are
# the guarantees the rest of the app relies on when it sends a command.
RSpec.describe "the command bus chain" do
  let(:command_bus) { Rails.configuration.command_bus }
  let(:event_store) { Rails.configuration.event_store }

  before do
    stub_const("Spec::ChainFact", Class.new(Fact) do
      def stream_names
        [ "Chain$#{data.fetch(:tid)}" ]
      end
    end)
    Spec::ChainFact.const_set(:SCHEMA, { tid: String }.freeze)

    stub_const("Spec::PublishThenMaybeFail", Class.new do
      include Command::Executable

      attribute :tid, String
      attribute :explode, TrueClass

      validates :tid, presence: true

      def call
        event_store.publish(Spec::ChainFact.strict(data: { tid: tid }))
        raise "boom" if explode
      end
    end)
  end

  it "publishes the facts a command produces" do
    command_bus.call(Spec::PublishThenMaybeFail.new(tid: "ok-1", explode: false))

    expect(event_store.read.stream("Chain$ok-1").count).to eq(1)
  end

  it "rolls the facts back when the command raises" do
    expect {
      command_bus.call(Spec::PublishThenMaybeFail.new(tid: "bad-1", explode: true))
    }.to raise_error("boom")

    expect(event_store.read.stream("Chain$bad-1").count).to eq(0)
  end

  it "tags published facts with a correlation id" do
    command_bus.call(Spec::PublishThenMaybeFail.new(tid: "corr-1", explode: false))

    fact = event_store.read.stream("Chain$corr-1").first

    expect(fact.metadata[:correlation_id]).to be_present
    expect(fact.metadata[:command]).to eq("Spec::PublishThenMaybeFail")
  end

  it "keeps one correlation id across a nested command" do
    stub_const("Spec::Outer", Class.new do
      include Command::Executable
      include CommandBusInjector

      attribute :tid, String

      def call
        event_store.publish(Spec::ChainFact.strict(data: { tid: "#{tid}-outer" }))
        command_bus.call(Spec::PublishThenMaybeFail.new(tid: "#{tid}-inner", explode: false))
      end
    end)

    command_bus.call(Spec::Outer.new(tid: "nest"))

    outer = event_store.read.stream("Chain$nest-outer").first
    inner = event_store.read.stream("Chain$nest-inner").first

    expect(inner.metadata[:correlation_id]).to eq(outer.metadata[:correlation_id])
  end

  it "instruments each command" do
    events = []
    subscriber = ActiveSupport::Notifications.subscribe(Command::Instrumentation::NAMESPACE) do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    command_bus.call(Spec::PublishThenMaybeFail.new(tid: "instr-1", explode: false))

    expect(events.map { |e| e.payload[:command] }).to include("Spec::PublishThenMaybeFail")
    expect(events.last.payload[:result]).to eq(:ok)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
