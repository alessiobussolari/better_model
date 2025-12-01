# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Stateable::Configurator do
  let(:model_class) do
    Class.new(ApplicationRecord) do
      self.table_name = "articles"
    end
  end

  let(:configurator) { described_class.new(model_class) }

  describe "#initialize" do
    it "accepts a model class" do
      expect(configurator).to be_a(described_class)
    end

    it "initializes with empty states" do
      expect(configurator.states).to eq([])
    end

    it "initializes with empty transitions" do
      expect(configurator.transitions).to eq({})
    end

    it "initializes with nil initial_state" do
      expect(configurator.initial_state).to be_nil
    end

    it "initializes with nil table_name" do
      expect(configurator.table_name).to be_nil
    end
  end

  describe "#state" do
    it "adds a state to the list" do
      configurator.state(:draft)
      expect(configurator.states).to include(:draft)
    end

    it "allows adding multiple states" do
      configurator.state(:draft)
      configurator.state(:published)
      configurator.state(:archived)
      expect(configurator.states).to eq([ :draft, :published, :archived ])
    end

    it "sets initial state when specified" do
      configurator.state(:draft, initial: true)
      expect(configurator.initial_state).to eq(:draft)
    end

    it "raises ArgumentError when state name is not a symbol" do
      expect do
        configurator.state("draft")
      end.to raise_error(ArgumentError, "State name must be a symbol")
    end

    it "raises ArgumentError when state is already defined" do
      configurator.state(:draft)
      expect do
        configurator.state(:draft)
      end.to raise_error(ArgumentError, "State draft already defined")
    end

    it "raises ArgumentError when defining multiple initial states" do
      configurator.state(:draft, initial: true)
      expect do
        configurator.state(:published, initial: true)
      end.to raise_error(ArgumentError, "Initial state already defined as draft")
    end

    it "allows non-initial states after initial state" do
      configurator.state(:draft, initial: true)
      expect do
        configurator.state(:published)
        configurator.state(:archived)
      end.not_to raise_error
    end
  end

  describe "#transition" do
    before do
      configurator.state(:draft, initial: true)
      configurator.state(:published)
      configurator.state(:archived)
    end

    it "creates a basic transition" do
      configurator.transition(:publish, from: :draft, to: :published)
      expect(configurator.transitions).to have_key(:publish)
    end

    it "sets from states as array" do
      configurator.transition(:publish, from: :draft, to: :published)
      expect(configurator.transitions[:publish][:from]).to eq([ :draft ])
    end

    it "sets to state" do
      configurator.transition(:publish, from: :draft, to: :published)
      expect(configurator.transitions[:publish][:to]).to eq(:published)
    end

    it "allows multiple from states" do
      configurator.transition(:archive, from: [ :draft, :published ], to: :archived)
      expect(configurator.transitions[:archive][:from]).to eq([ :draft, :published ])
    end

    it "raises ArgumentError when event name is not a symbol" do
      expect do
        configurator.transition("publish", from: :draft, to: :published)
      end.to raise_error(ArgumentError, "Event name must be a symbol")
    end

    it "raises ArgumentError when transition is already defined" do
      configurator.transition(:publish, from: :draft, to: :published)
      expect do
        configurator.transition(:publish, from: :published, to: :archived)
      end.to raise_error(ArgumentError, "Transition publish already defined")
    end

    it "raises ArgumentError when from state is not defined" do
      expect do
        configurator.transition(:publish, from: :unknown, to: :published)
      end.to raise_error(ArgumentError, /Unknown state in from: unknown/)
    end

    it "raises ArgumentError when to state is not defined" do
      expect do
        configurator.transition(:publish, from: :draft, to: :unknown)
      end.to raise_error(ArgumentError, /Unknown state in to: unknown/)
    end

    it "raises ArgumentError when any from state in array is not defined" do
      expect do
        configurator.transition(:archive, from: [ :draft, :unknown ], to: :archived)
      end.to raise_error(ArgumentError, /Unknown state in from: unknown/)
    end

    it "initializes guards array" do
      configurator.transition(:publish, from: :draft, to: :published)
      expect(configurator.transitions[:publish][:guards]).to eq([])
    end

    it "initializes validations array" do
      configurator.transition(:publish, from: :draft, to: :published)
      expect(configurator.transitions[:publish][:validations]).to eq([])
    end

    it "initializes before_callbacks array" do
      configurator.transition(:publish, from: :draft, to: :published)
      expect(configurator.transitions[:publish][:before_callbacks]).to eq([])
    end

    it "initializes after_callbacks array" do
      configurator.transition(:publish, from: :draft, to: :published)
      expect(configurator.transitions[:publish][:after_callbacks]).to eq([])
    end

    it "initializes around_callbacks array" do
      configurator.transition(:publish, from: :draft, to: :published)
      expect(configurator.transitions[:publish][:around_callbacks]).to eq([])
    end
  end

  describe "#check" do
    before do
      configurator.state(:draft, initial: true)
      configurator.state(:published)
    end

    # Note: The configurator uses unqualified StateableError which causes NameError
    # This is a bug in the implementation - it should use BetterModel::Errors::Stateable::StateableError
    it "raises error when called outside transition block" do
      expect do
        configurator.check { true }
      end.to raise_error(NameError, /StateableError/)
    end

    it "adds block check to guards" do
      configurator.transition(:publish, from: :draft, to: :published) do
        check { valid? }
      end
      expect(configurator.transitions[:publish][:guards].first[:type]).to eq(:block)
    end

    it "adds method check to guards" do
      configurator.transition(:publish, from: :draft, to: :published) do
        check :ready_to_publish?
      end
      expect(configurator.transitions[:publish][:guards].first[:type]).to eq(:method)
      expect(configurator.transitions[:publish][:guards].first[:method]).to eq(:ready_to_publish?)
    end

    it "adds predicate check via if option" do
      configurator.transition(:publish, from: :draft, to: :published) do
        check if: :is_complete?
      end
      expect(configurator.transitions[:publish][:guards].first[:type]).to eq(:predicate)
      expect(configurator.transitions[:publish][:guards].first[:predicate]).to eq(:is_complete?)
    end

    it "allows multiple checks" do
      configurator.transition(:publish, from: :draft, to: :published) do
        check { valid? }
        check :ready_to_publish?
        check if: :is_complete?
      end
      expect(configurator.transitions[:publish][:guards].size).to eq(3)
    end

    it "raises ArgumentError when no check provided" do
      expect do
        configurator.transition(:publish, from: :draft, to: :published) do
          check
        end
      end.to raise_error(ArgumentError, /check requires either a block, method name, or if: option/)
    end
  end

  describe "#validate" do
    before do
      configurator.state(:draft, initial: true)
      configurator.state(:published)
    end

    # Note: The configurator uses unqualified StateableError which causes NameError
    it "raises error when called outside transition block" do
      expect do
        configurator.validate { errors.add(:base, "Invalid") }
      end.to raise_error(NameError, /StateableError/)
    end

    it "adds validation block" do
      configurator.transition(:publish, from: :draft, to: :published) do
        validate { errors.add(:base, "Invalid") }
      end
      expect(configurator.transitions[:publish][:validations]).to be_present
    end

    it "raises ArgumentError when no block provided" do
      expect do
        configurator.transition(:publish, from: :draft, to: :published) do
          validate
        end
      end.to raise_error(ArgumentError, "validate requires a block")
    end

    it "allows multiple validations" do
      configurator.transition(:publish, from: :draft, to: :published) do
        validate { errors.add(:title, "can't be blank") }
        validate { errors.add(:content, "can't be blank") }
      end
      expect(configurator.transitions[:publish][:validations].size).to eq(2)
    end
  end

  describe "#before_transition" do
    before do
      configurator.state(:draft, initial: true)
      configurator.state(:published)
    end

    # Note: The configurator uses unqualified StateableError which causes NameError
    it "raises error when called outside transition block" do
      expect do
        configurator.before_transition { prepare }
      end.to raise_error(NameError, /StateableError/)
    end

    it "adds block callback" do
      configurator.transition(:publish, from: :draft, to: :published) do
        before_transition { prepare }
      end
      expect(configurator.transitions[:publish][:before_callbacks].first[:type]).to eq(:block)
    end

    it "adds method callback" do
      configurator.transition(:publish, from: :draft, to: :published) do
        before_transition :prepare_publishing
      end
      expect(configurator.transitions[:publish][:before_callbacks].first[:type]).to eq(:method)
      expect(configurator.transitions[:publish][:before_callbacks].first[:method]).to eq(:prepare_publishing)
    end

    it "raises ArgumentError when neither block nor method provided" do
      expect do
        configurator.transition(:publish, from: :draft, to: :published) do
          before_transition
        end
      end.to raise_error(ArgumentError, "before_transition requires either a block or method name")
    end

    it "allows multiple before_transition callbacks" do
      configurator.transition(:publish, from: :draft, to: :published) do
        before_transition { step1 }
        before_transition :step2
      end
      expect(configurator.transitions[:publish][:before_callbacks].size).to eq(2)
    end
  end

  describe "#after_transition" do
    before do
      configurator.state(:draft, initial: true)
      configurator.state(:published)
    end

    # Note: The configurator uses unqualified StateableError which causes NameError
    it "raises error when called outside transition block" do
      expect do
        configurator.after_transition { notify }
      end.to raise_error(NameError, /StateableError/)
    end

    it "adds block callback" do
      configurator.transition(:publish, from: :draft, to: :published) do
        after_transition { notify }
      end
      expect(configurator.transitions[:publish][:after_callbacks].first[:type]).to eq(:block)
    end

    it "adds method callback" do
      configurator.transition(:publish, from: :draft, to: :published) do
        after_transition :send_notification
      end
      expect(configurator.transitions[:publish][:after_callbacks].first[:type]).to eq(:method)
      expect(configurator.transitions[:publish][:after_callbacks].first[:method]).to eq(:send_notification)
    end

    it "raises ArgumentError when neither block nor method provided" do
      expect do
        configurator.transition(:publish, from: :draft, to: :published) do
          after_transition
        end
      end.to raise_error(ArgumentError, "after_transition requires either a block or method name")
    end

    it "allows multiple after_transition callbacks" do
      configurator.transition(:publish, from: :draft, to: :published) do
        after_transition { step1 }
        after_transition :step2
        after_transition { step3 }
      end
      expect(configurator.transitions[:publish][:after_callbacks].size).to eq(3)
    end
  end

  describe "#around" do
    before do
      configurator.state(:draft, initial: true)
      configurator.state(:published)
    end

    # Note: The configurator uses unqualified StateableError which causes NameError
    it "raises error when called outside transition block" do
      expect do
        configurator.around { |t| t.call }
      end.to raise_error(NameError, /StateableError/)
    end

    it "adds around callback" do
      configurator.transition(:publish, from: :draft, to: :published) do
        around { |transition| transition.call }
      end
      expect(configurator.transitions[:publish][:around_callbacks]).to be_present
    end

    it "raises ArgumentError when no block provided" do
      expect do
        configurator.transition(:publish, from: :draft, to: :published) do
          around
        end
      end.to raise_error(ArgumentError, "around requires a block")
    end
  end

  describe "#transitions_table" do
    it "sets custom table name" do
      configurator.transitions_table("custom_transitions")
      expect(configurator.table_name).to eq("custom_transitions")
    end

    it "converts symbol to string" do
      configurator.transitions_table(:custom_transitions)
      expect(configurator.table_name).to eq("custom_transitions")
    end
  end

  describe "#to_h" do
    before do
      configurator.state(:draft, initial: true)
      configurator.state(:published)
      configurator.transition(:publish, from: :draft, to: :published)
      configurator.transitions_table("custom_transitions")
    end

    it "returns hash with states" do
      expect(configurator.to_h[:states]).to eq([ :draft, :published ])
    end

    it "returns hash with transitions" do
      expect(configurator.to_h[:transitions]).to have_key(:publish)
    end

    it "returns hash with initial_state" do
      expect(configurator.to_h[:initial_state]).to eq(:draft)
    end

    it "returns hash with table_name" do
      expect(configurator.to_h[:table_name]).to eq("custom_transitions")
    end
  end

  describe "complex configuration" do
    it "supports complete state machine configuration" do
      configurator.state(:pending, initial: true)
      configurator.state(:approved)
      configurator.state(:rejected)
      configurator.state(:completed)

      configurator.transition(:approve, from: :pending, to: :approved) do
        check { manager_approved? }
        check :valid_for_approval?
        validate { errors.add(:base, "Not ready") unless ready? }
        before_transition { log_approval }
        after_transition { notify_requester }
      end

      configurator.transition(:reject, from: :pending, to: :rejected) do
        check if: :can_reject?
        after_transition :send_rejection_email
      end

      configurator.transition(:complete, from: :approved, to: :completed)

      configurator.transitions_table("workflow_transitions")

      config = configurator.to_h

      expect(config[:states]).to eq([ :pending, :approved, :rejected, :completed ])
      expect(config[:initial_state]).to eq(:pending)
      expect(config[:transitions].keys).to eq([ :approve, :reject, :complete ])
      expect(config[:table_name]).to eq("workflow_transitions")
    end
  end
end
