require "rails_helper"

RSpec.describe Handler::Idempotency, type: :model do
  let(:fact) do
    stub_const("Spec::Thing", Class.new(Fact) do
      def stream_names = [ "Thing$1" ]
    end)
    Spec::Thing.const_set(:SCHEMA, {}.freeze)
    Spec::Thing.strict(data: {})
  end

  def handler_running(&block)
    klass = Class.new do
      include Handler::Idempotency
      def self.name = "Spec::IdempotentHandler"

      def initialize(work) = @work = work
      def call(fact) = process_once(fact) { @work.call }
    end

    klass.new(block)
  end

  it "does the work the first time" do
    done = 0

    expect(handler_running { done += 1 }.call(fact)).to be(true)
    expect(done).to eq(1)
  end

  it "skips work it has already done" do
    done = 0
    handler_running { done += 1 }.call(fact)

    expect(handler_running { done += 1 }.call(fact)).to be(false)
    expect(done).to eq(1)
  end

  it "records a claim per handler, not globally" do
    handler_running { nil }.call(fact)

    expect(ProcessedFact.where(event_id: fact.event_id).count).to eq(1)
  end

  it "rolls the claim back when the work fails, so a retry can redo it" do
    expect { handler_running { raise "boom" }.call(fact) }.to raise_error("boom")

    expect(ProcessedFact.count).to eq(0)
  end

  # The bug: process_once rescued RecordNotUnique from anywhere inside the
  # transaction, not just from the claim insert. A collision raised by the work
  # itself -- say find_or_create_by! racing another worker on a unique index --
  # was swallowed as "already applied". The savepoint rolled back, the claim
  # vanished, the job returned success, and the fact was never applied. Silently
  # lost, which is precisely what this module exists to prevent.
  describe "a uniqueness collision raised by the work itself" do
    let(:collision) { ActiveRecord::RecordNotUnique.new("duplicate key value violates unique constraint") }

    it "is not mistaken for a duplicate delivery" do
      expect { handler_running { raise collision }.call(fact) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "leaves no claim behind, so the retry can apply the fact" do
      begin
        handler_running { raise collision }.call(fact)
      rescue ActiveRecord::RecordNotUnique
        # expected
      end

      expect(ProcessedFact.count).to eq(0)
    end
  end
end
