# frozen_string_literal: true

module BetterModel
  module Concerns
    # Shared concern for module enabled checks
    #
    # This module provides reusable methods for checking if a BetterModel module
    # is enabled and raising appropriate errors when methods are called on
    # non-enabled modules.
    #
    # @example Including in a module
    #   module BetterModel
    #     module Archivable
    #       extend ActiveSupport::Concern
    #       include BetterModel::Concerns::EnabledCheck
    #
    #       def archive!
    #         ensure_module_enabled!(:archivable, BetterModel::Errors::Archivable::NotEnabledError)
    #         # ... rest of the method
    #       end
    #     end
    #   end
    #
    module EnabledCheck
      extend ActiveSupport::Concern

      # Instance method to ensure module is enabled (raises error if not)
      #
      # @param module_name [Symbol] The module name (e.g., :archivable, :traceable)
      # @param error_class [Class] The error class to raise (e.g., NotEnabledError)
      # @param message [String] Custom error message (optional)
      # @raise [error_class] If the module is not enabled
      # @return [void]
      def ensure_module_enabled!(module_name, error_class, message: nil)
        enabled_method = :"#{module_name}_enabled?"

        unless self.class.respond_to?(enabled_method) && self.class.public_send(enabled_method)
          raise error_class, message || "Module is not enabled"
        end
      end

      # Instance method to return default value if module not enabled
      #
      # @param module_name [Symbol] The module name (e.g., :archivable, :traceable)
      # @param default [Object] The default value to return if not enabled
      # @yield The block to execute if module is enabled
      # @return [Object] Either the default value or the block result
      def if_module_enabled(module_name, default: nil)
        enabled_method = :"#{module_name}_enabled?"

        if self.class.respond_to?(enabled_method) && self.class.public_send(enabled_method)
          yield if block_given?
        else
          default
        end
      end

      # Class methods for enabled checks
      module ClassMethods
        # Class method to ensure module is enabled (raises error if not)
        #
        # @param module_name [Symbol] The module name (e.g., :archivable, :traceable)
        # @param error_class [Class] The error class to raise (e.g., NotEnabledError)
        # @param message [String] Custom error message (optional)
        # @raise [error_class] If the module is not enabled
        # @return [void]
        def ensure_module_enabled!(module_name, error_class, message: nil)
          enabled_method = :"#{module_name}_enabled?"

          unless respond_to?(enabled_method) && public_send(enabled_method)
            raise error_class, message || "Module is not enabled"
          end
        end

        # Class method to return default value if module not enabled
        #
        # @param module_name [Symbol] The module name (e.g., :archivable, :traceable)
        # @param default [Object] The default value to return if not enabled
        # @yield The block to execute if module is enabled
        # @return [Object] Either the default value or the block result
        def if_module_enabled(module_name, default: nil)
          enabled_method = :"#{module_name}_enabled?"

          if respond_to?(enabled_method) && public_send(enabled_method)
            yield if block_given?
          else
            default
          end
        end
      end
    end
  end
end
