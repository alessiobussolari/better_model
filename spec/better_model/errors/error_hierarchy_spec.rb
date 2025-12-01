# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Error Hierarchy", type: :unit do
  describe "BetterModel::Errors::BetterModelError" do
    it "inherits from StandardError" do
      expect(BetterModel::Errors::BetterModelError).to be < StandardError
    end

    it "can be instantiated with a message" do
      error = BetterModel::Errors::BetterModelError.new("test message")
      expect(error.message).to eq("test message")
    end

    it "can be raised and caught" do
      expect do
        raise BetterModel::Errors::BetterModelError, "test"
      end.to raise_error(BetterModel::Errors::BetterModelError)
    end

    it "can be caught as StandardError" do
      expect do
        raise BetterModel::Errors::BetterModelError, "test"
      end.to raise_error(StandardError)
    end
  end

  describe "Module Base Errors" do
    describe "Searchable::SearchableError" do
      it "inherits from BetterModelError" do
        expect(BetterModel::Errors::Searchable::SearchableError).to be < BetterModel::Errors::BetterModelError
      end

      it "can be caught as BetterModelError" do
        expect do
          raise BetterModel::Errors::Searchable::SearchableError, "test"
        end.to raise_error(BetterModel::Errors::BetterModelError)
      end
    end

    describe "Stateable::StateableError" do
      it "inherits from BetterModelError" do
        expect(BetterModel::Errors::Stateable::StateableError).to be < BetterModel::Errors::BetterModelError
      end
    end

    describe "Validatable::ValidatableError" do
      it "inherits from BetterModelError" do
        expect(BetterModel::Errors::Validatable::ValidatableError).to be < BetterModel::Errors::BetterModelError
      end
    end

    describe "Archivable::ArchivableError" do
      it "inherits from BetterModelError" do
        expect(BetterModel::Errors::Archivable::ArchivableError).to be < BetterModel::Errors::BetterModelError
      end
    end

    describe "Traceable::TraceableError" do
      it "inherits from BetterModelError" do
        expect(BetterModel::Errors::Traceable::TraceableError).to be < BetterModel::Errors::BetterModelError
      end
    end

    describe "Taggable::TaggableError" do
      it "inherits from BetterModelError" do
        expect(BetterModel::Errors::Taggable::TaggableError).to be < BetterModel::Errors::BetterModelError
      end
    end

    describe "Permissible::PermissibleError" do
      it "inherits from BetterModelError" do
        expect(BetterModel::Errors::Permissible::PermissibleError).to be < BetterModel::Errors::BetterModelError
      end
    end

    describe "Predicable::PredicableError" do
      it "inherits from BetterModelError" do
        expect(BetterModel::Errors::Predicable::PredicableError).to be < BetterModel::Errors::BetterModelError
      end
    end

    describe "Sortable::SortableError" do
      it "inherits from BetterModelError" do
        expect(BetterModel::Errors::Sortable::SortableError).to be < BetterModel::Errors::BetterModelError
      end
    end

    describe "Statusable::StatusableError" do
      it "inherits from BetterModelError" do
        expect(BetterModel::Errors::Statusable::StatusableError).to be < BetterModel::Errors::BetterModelError
      end
    end
  end

  describe "ConfigurationError classes (ArgumentError inheritance)" do
    %w[
      Searchable
      Stateable
      Validatable
      Archivable
      Traceable
      Taggable
      Permissible
      Predicable
      Sortable
      Statusable
    ].each do |module_name|
      describe "#{module_name}::ConfigurationError" do
        let(:error_class) { "BetterModel::Errors::#{module_name}::ConfigurationError".constantize }

        it "inherits from ArgumentError" do
          expect(error_class).to be < ArgumentError
        end

        it "can be caught as ArgumentError" do
          expect do
            raise error_class, "test"
          end.to raise_error(ArgumentError)
        end

        it "does NOT inherit from BetterModelError" do
          expect(error_class < BetterModel::Errors::BetterModelError).to be_falsy
        end

        it "can be instantiated with message" do
          error = error_class.new("configuration issue")
          expect(error.message).to eq("configuration issue")
        end
      end
    end
  end

  describe "Searchable Specific Errors" do
    describe "InvalidPredicateError" do
      it "inherits from SearchableError" do
        expect(BetterModel::Errors::Searchable::InvalidPredicateError).to be < BetterModel::Errors::Searchable::SearchableError
      end

      it "can be caught as BetterModelError" do
        expect do
          raise BetterModel::Errors::Searchable::InvalidPredicateError, "invalid predicate"
        end.to raise_error(BetterModel::Errors::BetterModelError)
      end
    end

    describe "InvalidOrderError" do
      it "inherits from SearchableError" do
        expect(BetterModel::Errors::Searchable::InvalidOrderError).to be < BetterModel::Errors::Searchable::SearchableError
      end
    end

    describe "InvalidPaginationError" do
      it "inherits from SearchableError" do
        expect(BetterModel::Errors::Searchable::InvalidPaginationError).to be < BetterModel::Errors::Searchable::SearchableError
      end
    end

    describe "InvalidSecurityError" do
      it "inherits from SearchableError" do
        expect(BetterModel::Errors::Searchable::InvalidSecurityError).to be < BetterModel::Errors::Searchable::SearchableError
      end
    end
  end

  describe "Stateable Specific Errors" do
    describe "InvalidTransitionError" do
      it "inherits from StateableError" do
        expect(BetterModel::Errors::Stateable::InvalidTransitionError).to be < BetterModel::Errors::Stateable::StateableError
      end
    end

    describe "CheckFailedError" do
      it "inherits from StateableError" do
        expect(BetterModel::Errors::Stateable::CheckFailedError).to be < BetterModel::Errors::Stateable::StateableError
      end

      it "has GuardFailedError alias for backward compatibility" do
        expect(BetterModel::Errors::Stateable::GuardFailedError).to eq(BetterModel::Errors::Stateable::CheckFailedError)
      end
    end

    describe "ValidationFailedError" do
      it "inherits from StateableError" do
        expect(BetterModel::Errors::Stateable::ValidationFailedError).to be < BetterModel::Errors::Stateable::StateableError
      end
    end

    describe "NotEnabledError" do
      it "inherits from StateableError" do
        expect(BetterModel::Errors::Stateable::NotEnabledError).to be < BetterModel::Errors::Stateable::StateableError
      end
    end

    describe "InvalidStateError" do
      it "inherits from StateableError" do
        expect(BetterModel::Errors::Stateable::InvalidStateError).to be < BetterModel::Errors::Stateable::StateableError
      end
    end
  end

  describe "Archivable Specific Errors" do
    describe "AlreadyArchivedError" do
      it "inherits from ArchivableError" do
        expect(BetterModel::Errors::Archivable::AlreadyArchivedError).to be < BetterModel::Errors::Archivable::ArchivableError
      end
    end

    describe "NotArchivedError" do
      it "inherits from ArchivableError" do
        expect(BetterModel::Errors::Archivable::NotArchivedError).to be < BetterModel::Errors::Archivable::ArchivableError
      end
    end

    describe "NotEnabledError" do
      it "inherits from ArchivableError" do
        expect(BetterModel::Errors::Archivable::NotEnabledError).to be < BetterModel::Errors::Archivable::ArchivableError
      end
    end
  end

  describe "Validatable Specific Errors" do
    describe "NotEnabledError" do
      it "inherits from ValidatableError" do
        expect(BetterModel::Errors::Validatable::NotEnabledError).to be < BetterModel::Errors::Validatable::ValidatableError
      end
    end
  end

  describe "Traceable Specific Errors" do
    describe "NotEnabledError" do
      it "inherits from TraceableError" do
        expect(BetterModel::Errors::Traceable::NotEnabledError).to be < BetterModel::Errors::Traceable::TraceableError
      end
    end
  end
end
