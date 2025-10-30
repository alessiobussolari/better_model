# frozen_string_literal: true

module BetterModel
  module Validatable
    # Validator per validazioni di ordine tra campi (cross-field)
    #
    # Verifica che un campo sia in una relazione d'ordine rispetto ad un altro campo.
    # Supporta date/time (before/after) e numeri (lteq/gteq/lt/gt).
    #
    # Esempio:
    #   validates_with OrderValidator,
    #                  attributes: [:starts_at],
    #                  second_field: :ends_at,
    #                  comparator: :before
    #
    class OrderValidator < ActiveModel::EachValidator
      COMPARATORS = {
        before: :<,
        after: :>,
        lteq: :<=,
        gteq: :>=,
        lt: :<,
        gt: :>
      }.freeze

      def initialize(options)
        super

        @second_field = options[:second_field]
        @comparator = options[:comparator]

        unless @second_field
          raise ArgumentError, "OrderValidator requires :second_field option"
        end

        unless COMPARATORS.key?(@comparator)
          raise ArgumentError, "Invalid comparator: #{@comparator}. Valid: #{COMPARATORS.keys.join(', ')}"
        end
      end

      def validate_each(record, attribute, value)
        second_value = record.send(@second_field)

        # Skip validation if either field is nil (use presence validation for that)
        return if value.nil? || second_value.nil?

        # Get the comparison operator
        operator = COMPARATORS[@comparator]

        # Perform comparison
        unless value.send(operator, second_value)
          record.errors.add(attribute, error_message(attribute, @comparator, @second_field))
        end
      end

      private

      def error_message(first_field, comparator, second_field)
        # Messaggi user-friendly basati sul comparatore
        case comparator
        when :before
          "must be before #{second_field.to_s.humanize.downcase}"
        when :after
          "must be after #{second_field.to_s.humanize.downcase}"
        when :lteq
          "must be less than or equal to #{second_field.to_s.humanize.downcase}"
        when :gteq
          "must be greater than or equal to #{second_field.to_s.humanize.downcase}"
        when :lt
          "must be less than #{second_field.to_s.humanize.downcase}"
        when :gt
          "must be greater than #{second_field.to_s.humanize.downcase}"
        end
      end
    end
  end
end
