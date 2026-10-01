require "rails_helper"

RSpec.describe ApplicationEventStore do
  subject(:event_store) { Rails.configuration.event_store }

  before do
    stub_const("MultiStreamFact", Class.new(Fact) do
      def stream_names
        [ "Primary$#{data.fetch(:tid)}", "Secondary$#{data.fetch(:owner)}" ]
      end
    end)

    MultiStreamFact.const_set(:SCHEMA, { tid: String, owner: String }.freeze)
  end

  it "publishes into the first stream and links into the others" do
    fact = MultiStreamFact.strict(data: { tid: "evt-1", owner: "user-1" })

    event_store.publish(fact)

    expect(event_store.read.stream("Primary$evt-1").to_a.map(&:event_id))
      .to eq([ fact.event_id ])
    expect(event_store.read.stream("Secondary$user-1").to_a.map(&:event_id))
      .to eq([ fact.event_id ])
  end

  it "stores the fact once, however many streams it names" do
    fact = MultiStreamFact.strict(data: { tid: "evt-2", owner: "user-2" })

    event_store.publish(fact)

    expect(event_store.read.to_a.size).to eq(1)
  end

  it "refuses a fact that names no stream" do
    stub_const("UnroutedFact", Class.new(Fact) do
      def stream_names
        []
      end
    end)
    UnroutedFact.const_set(:SCHEMA, {}.freeze)

    expect { event_store.publish(UnroutedFact.strict(data: {})) }
      .to raise_error(ArgumentError, /declared no stream names/)
  end
end
