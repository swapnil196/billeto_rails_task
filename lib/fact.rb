# frozen_string_literal: true

class Fact < RubyEventStore::Event
  SchemaViolation = Class.new(StandardError)

  class << self
    def strict(data:, metadata: {})
      validate!(data)
      new(data: data, metadata: metadata)
    end

    def schema
      unless const_defined?(:SCHEMA, false)
        raise NotImplementedError, "#{name} must declare a SCHEMA constant"
      end

      const_get(:SCHEMA, false)
    end

    private

    def validate!(data)
      unless data.is_a?(Hash)
        raise SchemaViolation, "#{name} expects a Hash payload, got #{data.class}"
      end

      missing = schema.keys - data.keys
      unexpected = data.keys - schema.keys

      problems = []
      problems << "missing keys: #{missing.join(', ')}" if missing.any?
      problems << "unexpected keys: #{unexpected.join(', ')}" if unexpected.any?
      problems.concat(type_errors(data))

      return if problems.empty?

      raise SchemaViolation, "#{name}: #{problems.join('; ')}"
    end

    def type_errors(data)
      schema.filter_map do |key, expected|
        next unless data.key?(key)

        value = data.fetch(key)
        permitted = Array(expected)
        next if permitted.any? { |type| value.is_a?(type) }

        "#{key} expected #{permitted.join(' or ')}, got #{value.class}"
      end
    end
  end

  def stream_names
    raise NotImplementedError, "#{self.class.name} must declare #stream_names"
  end
end
