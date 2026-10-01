require "rails_helper"

RSpec.describe Command::Bus do
  let(:bus) { Command::Bus.new }

  before do
    stub_const("Spec::CountUp", Class.new do
      include Command::Executable

      attribute :by, Integer
      validates :by, presence: true

      cattr_accessor :total, default: 0

      def call
        self.class.total += by
      end
    end)

    stub_const("Spec::Unhandleable", Class.new do
      include Command::Attributes
    end)

    Spec::CountUp.total = 0
  end

  it "executes a self-executing command without registration" do
    bus.call(Spec::CountUp.new(by: 3))

    expect(Spec::CountUp.total).to eq(3)
  end

  it "refuses a command that fails its own validations" do
    expect { bus.call(Spec::CountUp.new(by: nil)) }
      .to raise_error(Command::Invalid, /can't be blank/)
  end

  it "does not run an invalid command" do
    begin
      bus.call(Spec::CountUp.new(by: nil))
    rescue Command::Invalid
      # expected
    end

    expect(Spec::CountUp.total).to eq(0)
  end

  it "refuses a command that cannot carry out its own work" do
    expect { bus.call(Spec::Unhandleable.new) }
      .to raise_error(Command::Unhandled, /is not executable/)
  end
end
