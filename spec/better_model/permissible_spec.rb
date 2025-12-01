# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Permissible do
  let(:article) { create(:article, status: "draft", view_count: 0) }

  describe "basic permission definition and checking" do
    let(:test_class) do
      create_permissible_class("PermissibleTest1") do
        permit :delete, -> { status != "published" }
      end
    end

    it "defines permission with lambda" do
      expect(test_class.permission_defined?(:delete)).to be true
    end

    it "checks permission with permit? method" do
      instance = test_class.new(status: "draft")
      expect(instance.permit?(:delete)).to be true

      instance.status = "published"
      expect(instance.permit?(:delete)).to be false
    end

    it "returns false for undefined permission" do
      instance = test_class.new
      expect(instance.permit?(:nonexistent_permission)).to be false
    end
  end

  describe "dynamic method generation" do
    let(:test_class) do
      create_permissible_class("PermissibleTest2") do
        permit :delete, -> { true }
        permit :edit, -> { true }
      end
    end

    it "generates dynamic permit_permission? methods" do
      instance = test_class.new
      expect(instance).to respond_to(:permit_delete?)
      expect(instance).to respond_to(:permit_edit?)
    end

    it "returns correct values for dynamic methods" do
      test_class2 = create_permissible_class("PermissibleTest3") do
        permit :delete, -> { status == "draft" }
        permit :edit, -> { status != "archived" }
      end

      instance = test_class2.new(status: "draft")
      expect(instance.permit_delete?).to be true
      expect(instance.permit_edit?).to be true

      instance.status = "published"
      expect(instance.permit_delete?).to be false
      expect(instance.permit_edit?).to be true
    end
  end

  describe "permissions with complex conditions" do
    it "handles permissions referencing statuses" do
      test_class = create_permissible_class("PermissibleTest4") do
        include BetterModel::Statusable

        is :draft, -> { status == "draft" }
        is :published, -> { status == "published" }

        permit :delete, -> { is?(:draft) }
        permit :edit, -> { is?(:draft) || is?(:published) }
      end

      instance = test_class.new(status: "draft")
      expect(instance.permit_delete?).to be true
      expect(instance.permit_edit?).to be true

      instance.status = "published"
      expect(instance.permit_delete?).to be false
      expect(instance.permit_edit?).to be true
    end

    it "handles time-based permissions" do
      test_class = create_permissible_class("PermissibleTest5") do
        permit :archive, -> { created_at.present? && created_at < 1.year.ago }
      end

      instance = test_class.new(created_at: 2.years.ago)
      expect(instance.permit_archive?).to be true

      instance.created_at = 1.day.ago
      expect(instance.permit_archive?).to be false
    end

    it "handles compound conditions" do
      test_class = create_permissible_class("PermissibleTest6") do
        permit :publish, -> { status == "draft" && title.present? && content.present? }
      end

      instance = test_class.new(status: "draft", title: "Title", content: "Content")
      expect(instance.permit_publish?).to be true

      instance.title = nil
      expect(instance.permit_publish?).to be false
    end
  end

  describe "#permissions" do
    let(:test_class) do
      create_permissible_class("PermissibleTest7") do
        permit :delete, -> { true }
        permit :edit, -> { false }
      end
    end

    it "returns hash of all permissions" do
      instance = test_class.new
      perms = instance.permissions

      expect(perms).to be_a(Hash)
      expect(perms.keys).to include(:delete, :edit)
      expect(perms[:delete]).to be true
      expect(perms[:edit]).to be false
    end

    it "has all defined permissions" do
      test_class2 = create_permissible_class("PermissibleTest8") do
        permit :delete, -> { true }
        permit :edit, -> { true }
        permit :publish, -> { true }
      end

      instance = test_class2.new
      perms = instance.permissions
      expected_permissions = %i[delete edit publish]

      expect(perms.keys.sort).to eq(expected_permissions.sort)
    end

    it "reflects current state" do
      test_class2 = create_permissible_class("PermissibleTest9") do
        permit :delete, -> { status == "draft" }
        permit :edit, -> { status != "archived" }
        permit :publish, -> { status == "draft" }
      end

      instance = test_class2.new(status: "draft")
      perms = instance.permissions

      expect(perms[:delete]).to be true
      expect(perms[:edit]).to be true
      expect(perms[:publish]).to be true

      instance.status = "published"
      perms = instance.permissions

      expect(perms[:delete]).to be false
      expect(perms[:edit]).to be true
      expect(perms[:publish]).to be false
    end
  end

  describe "helper methods" do
    describe "#has_any_permission?" do
      it "returns true when at least one permission is granted" do
        test_class = create_permissible_class("PermissibleTest10") do
          permit :delete, -> { true }
          permit :edit, -> { false }
        end

        instance = test_class.new
        expect(instance.has_any_permission?).to be true
      end

      it "returns false when no permissions granted" do
        test_class = create_permissible_class("PermissibleTest11") do
          permit :delete, -> { false }
          permit :edit, -> { false }
        end

        instance = test_class.new
        expect(instance.has_any_permission?).to be false
      end
    end

    describe "#has_all_permissions?" do
      it "returns true when all specified permissions are granted" do
        test_class = create_permissible_class("PermissibleTest12") do
          permit :delete, -> { true }
          permit :edit, -> { true }
          permit :publish, -> { false }
        end

        instance = test_class.new
        expect(instance.has_all_permissions?(%i[delete edit])).to be true
        expect(instance.has_all_permissions?(%i[delete publish])).to be false
      end

      it "handles single permission" do
        test_class = create_permissible_class("PermissibleTest13") do
          permit :delete, -> { true }
        end

        instance = test_class.new
        expect(instance.has_all_permissions?([ :delete ])).to be true
      end

      it "handles empty array" do
        test_class = create_permissible_class("PermissibleTest14") do
          permit :delete, -> { true }
        end

        instance = test_class.new
        expect(instance.has_all_permissions?([])).to be true
      end
    end

    describe "#granted_permissions" do
      it "returns only granted permissions" do
        test_class = create_permissible_class("PermissibleTest15") do
          permit :delete, -> { true }
          permit :edit, -> { false }
          permit :publish, -> { true }
        end

        instance = test_class.new
        granted = instance.granted_permissions(%i[delete edit publish])

        expect(granted.sort).to eq(%i[delete publish].sort)
      end

      it "handles empty input" do
        test_class = create_permissible_class("PermissibleTest16") do
          permit :delete, -> { true }
        end

        instance = test_class.new
        expect(instance.granted_permissions([])).to eq([])
      end

      it "returns empty when no permissions are granted" do
        test_class = create_permissible_class("PermissibleTest17") do
          permit :delete, -> { false }
          permit :edit, -> { false }
        end

        instance = test_class.new
        expect(instance.granted_permissions(%i[delete edit])).to eq([])
      end
    end
  end

  describe "class methods" do
    describe ".defined_permissions" do
      it "returns all defined permission names" do
        test_class = create_permissible_class("PermissibleTest18") do
          permit :delete, -> { true }
          permit :edit, -> { true }
          permit :publish, -> { true }
        end

        permissions = test_class.defined_permissions
        expect(permissions).to be_an(Array)
        expected = %i[delete edit publish]
        expect(permissions.sort).to eq(expected.sort)
      end
    end

    describe ".permission_defined?" do
      it "returns true for defined permissions" do
        test_class = create_permissible_class("PermissibleTest19") do
          permit :delete, -> { true }
          permit :edit, -> { true }
        end

        expect(test_class.permission_defined?(:delete)).to be true
        expect(test_class.permission_defined?(:edit)).to be true
      end

      it "returns false for undefined permissions" do
        test_class = create_permissible_class("PermissibleTest20") do
          permit :delete, -> { true }
        end

        expect(test_class.permission_defined?(:nonexistent)).to be false
      end

      it "accepts string or symbol" do
        test_class = create_permissible_class("PermissibleTest21") do
          permit :delete, -> { true }
        end

        expect(test_class.permission_defined?(:delete)).to be true
        expect(test_class.permission_defined?("delete")).to be true
      end
    end
  end

  describe "#as_json" do
    it "does not include permissions by default" do
      test_class = create_permissible_class("PermissibleTest22") do
        permit :delete, -> { true }
      end

      instance = test_class.new
      json = instance.as_json

      expect(json.keys).not_to include("permissions")
    end

    it "includes permissions with include_permissions option" do
      test_class = create_permissible_class("PermissibleTest23") do
        permit :delete, -> { true }
      end

      instance = test_class.new
      json = instance.as_json(include_permissions: true)

      expect(json.keys).to include("permissions")
      expect(json["permissions"]).to be_a(Hash)
    end

    it "has string keys for permissions" do
      test_class = create_permissible_class("PermissibleTest24") do
        permit :delete, -> { true }
        permit :edit, -> { false }
      end

      instance = test_class.new
      json = instance.as_json(include_permissions: true)
      perms = json["permissions"]

      expect(perms.keys).to include("delete", "edit")
      expect(perms.keys).not_to include(:delete)
    end

    it "has correct boolean values" do
      test_class = create_permissible_class("PermissibleTest25") do
        permit :delete, -> { status == "draft" }
        permit :edit, -> { true }
      end

      instance = test_class.new(status: "draft")
      json = instance.as_json(include_permissions: true)
      perms = json["permissions"]

      expect(perms["delete"]).to be true
      expect(perms["edit"]).to be true
    end
  end

  describe "edge cases" do
    it "handles nil values in conditions gracefully" do
      test_class = create_permissible_class("PermissibleTest26") do
        permit :delete, -> { published_at.nil? }
      end

      instance = test_class.new(published_at: nil)
      expect(instance.permit_delete?).to be true

      instance.published_at = Time.current
      expect(instance.permit_delete?).to be false
    end

    it "handles permission name as string or symbol" do
      test_class = create_permissible_class("PermissibleTest27") do
        permit :delete, -> { true }
      end

      instance = test_class.new
      expect(instance.permit?(:delete)).to be true
      expect(instance.permit?("delete")).to be true
    end
  end

  describe "error handling" do
    it "raises ArgumentError when defining permission without condition" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible
          permit :test_permission
        end
      end.to raise_error(ArgumentError)
    end

    it "raises ArgumentError when defining permission with blank name" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible
          permit "", -> { true }
        end
      end.to raise_error(ArgumentError)
    end

    it "raises ArgumentError when defining permission with nil name" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible
          permit nil, -> { true }
        end
      end.to raise_error(ArgumentError)
    end

    it "raises ArgumentError when defining permission with non-callable condition" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible
          permit :test, "not a proc"
        end
      end.to raise_error(ArgumentError)
    end
  end

  describe "block syntax" do
    it "accepts block instead of lambda" do
      test_class = create_permissible_class("PermissibleTest28") do
        permit :delete do
          status == "draft"
        end
      end

      instance = test_class.new(status: "draft")
      expect(instance.permit?(:delete)).to be true
    end
  end

  describe "thread safety" do
    it "has frozen permit_definitions" do
      test_class = create_permissible_class("PermissibleTest29") do
        permit :delete, -> { true }
      end

      expect(test_class.permit_definitions).to be_frozen
    end

    it "has frozen individual conditions" do
      test_class = create_permissible_class("PermissibleTest30") do
        permit :delete, -> { true }
      end

      condition = test_class.permit_definitions[:delete]
      expect(condition).to be_frozen
    end
  end

  describe "inheritance" do
    it "subclasses inherit permission definitions" do
      parent_class = create_permissible_class("PermissibleTest31") do
        permit :delete, -> { true }
      end

      subclass = Class.new(parent_class)

      expect(subclass.permission_defined?(:delete)).to be true
    end

    it "subclasses can define additional permissions" do
      parent_class = create_permissible_class("PermissibleTest32") do
        permit :delete, -> { true }
      end

      subclass = Class.new(parent_class) do
        self.table_name = "articles"
        permit :custom_action, -> { view_count > 1000 }
      end

      expect(subclass.permission_defined?(:custom_action)).to be true
      expect(subclass.permission_defined?(:delete)).to be true
      expect(parent_class.permission_defined?(:custom_action)).to be false
    end
  end

  describe "ConfigurationError" do
    it "exists" do
      expect(defined?(BetterModel::Errors::Permissible::ConfigurationError)).to be_truthy
    end

    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Permissible::ConfigurationError).to be < ArgumentError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Permissible::ConfigurationError.new("test message")
      expect(error.message).to eq("test message")
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Permissible::ConfigurationError.new("test")
      end.to raise_error(ArgumentError)
    end
  end

  describe "ConfigurationError integration" do
    it "raises ConfigurationError when permission name is blank" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible
          permit "", -> { true }
        end
      end.to raise_error(BetterModel::Errors::Permissible::ConfigurationError, /Permission name cannot be blank/)
    end

    it "raises ConfigurationError when condition is missing" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible
          permit :delete
        end
      end.to raise_error(BetterModel::Errors::Permissible::ConfigurationError, /Condition proc or block is required/)
    end

    it "raises ConfigurationError when condition does not respond to call" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible
          permit :delete, "not a proc"
        end
      end.to raise_error(BetterModel::Errors::Permissible::ConfigurationError, /Condition must respond to call/)
    end
  end
end
