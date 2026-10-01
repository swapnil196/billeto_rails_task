require "rails_helper"

RSpec.describe Fact do
  before do
    stub_const("SampleFact", Class.new(Fact) do
      def stream_names
        [ "Sample$#{data.fetch(:tid)}" ]
      end
    end)

    SampleFact.const_set(:SCHEMA, {
      tid: String,
      votes: Integer,
      note: [ String, NilClass ]
    }.freeze)
  end

  describe ".strict" do
    it "builds the fact when the payload matches the schema" do
      fact = SampleFact.strict(data: { tid: "abc", votes: 2, note: nil })

      expect(fact.data).to eq(tid: "abc", votes: 2, note: nil)
    end

    it "rejects a payload that is missing a key" do
      expect {
        SampleFact.strict(data: { tid: "abc", votes: 2 })
      }.to raise_error(Fact::SchemaViolation, /missing keys: note/)
    end

    it "rejects a payload carrying a key the schema does not declare" do
      expect {
        SampleFact.strict(data: { tid: "abc", votes: 2, note: nil, extra: true })
      }.to raise_error(Fact::SchemaViolation, /unexpected keys: extra/)
    end

    it "rejects a value of the wrong type" do
      expect {
        SampleFact.strict(data: { tid: "abc", votes: "two", note: nil })
      }.to raise_error(Fact::SchemaViolation, /votes expected Integer, got String/)
    end

    it "accepts any of the types listed for an optional field" do
      expect {
        SampleFact.strict(data: { tid: "abc", votes: 1, note: "hello" })
      }.not_to raise_error
    end
  end

  describe ".schema" do
    it "refuses a subclass that declares no schema of its own" do
      stub_const("SchemalessFact", Class.new(Fact))

      expect { SchemalessFact.schema }
        .to raise_error(NotImplementedError, /must declare a SCHEMA/)
    end
  end

  describe "#stream_names" do
    it "is required" do
      stub_const("StreamlessFact", Class.new(Fact))
      StreamlessFact.const_set(:SCHEMA, {}.freeze)

      expect { StreamlessFact.strict(data: {}).stream_names }
        .to raise_error(NotImplementedError, /must declare #stream_names/)
    end
  end
end
