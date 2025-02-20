# frozen_string_literal: false

require 'bigdecimal'
require 'date'
require 'time'

require_relative 'error'

module Tomlib
  # TOML generator
  #
  # @api private
  class Dumper
    # Indent characters
    # @api private
    INDENT = '  '.freeze

    # Representation of Infinity in TOML
    # @api private
    INF_POSITIVE = 'inf'.freeze

    # Representation of negative Infinity in TOML
    # @api private
    INF_NEGATIVE = '-inf'.freeze

    # Representation of NaN in TOML
    # @api private
    NAN = 'nan'.freeze

    # Generate TOML string from ruby Hash
    #
    # @param [Hash] hash
    # @param [String, nil] base_key
    # @param [String] indent
    # @param [true, false] use_indent
    #
    # @return [String]
    #
    # @api private
    def dump(hash, base_key = nil, indent = '', use_indent: true)
      header = ''
      footer = ''

      hash.each do |key, value|
        toml_key = to_toml_key(key)

        if value.is_a?(Hash)
          compound_key = to_toml_compound_key(base_key, toml_key)
          next_indent = use_indent && base_key ? indent + INDENT : indent

          footer << "\n".freeze << next_indent << '['.freeze << compound_key << "]\n".freeze
          footer << dump(value, compound_key, next_indent, use_indent: use_indent)
        elsif value.is_a?(Array) && value.all? { |e| e.is_a?(Hash) }
          compound_key = to_toml_compound_key(base_key, toml_key)
          next_indent = use_indent && base_key ? indent + INDENT : indent

          value.each do |el|
            footer << "\n".freeze << next_indent << '[['.freeze << compound_key << "]]\n".freeze
            footer << dump(el, compound_key, next_indent, use_indent: use_indent)
          end
        else
          header << indent << toml_key << ' = '.freeze << to_toml_value(value) << "\n".freeze
        end
      end

      footer.gsub!(/\A\n/, ''.freeze) if header.empty?
      header << footer
    end

    private

    # Generate TOML key from Hash key
    #
    # @param [String] key
    # @param [true, false] use_indent
    #
    # @return [String]
    #
    # @api private
    def to_toml_key(key)
      raise DumpError, "'nil' can't be used as a key" if key.nil?

      key = key.to_s

      case key_type(key)
      when :quoted
        key.inspect
      when :escape
        key.dump.gsub('\n', '\\\\\n')
      else
        key
      end
    end

    # Concatenate key with base_key
    #
    # @param [String, nil] base_key
    # @param [String] key
    #
    # @return [String]
    #
    # @api private
    def to_toml_compound_key(base, key)
      return key unless base

      '' << base << '.'.freeze << key
    end

    # Generate TOML value from Ruby object
    #
    # @param [Object] value
    #
    # @return [String]
    #
    # @api private
    def to_toml_value(value)
      case value
      when String
        value.inspect
      when Float, BigDecimal
        to_toml_float(value)
      when Time, DateTime
        value.iso8601(3)
      when Date
        value.iso8601
      when Hash
        "{ #{value.map { |k, v| "#{to_toml_key(k)} = #{to_toml_value(v)}" }.join(', ')} }"
      when Array
        "[ #{value.map { |e| to_toml_value(e) }.join(', ')} ]"
      when nil
        '""'.freeze
      else
        value.to_s
      end
    end

    # Generate TOML float value from Ruby Float or BigDecimal
    #
    # @param [Float, BigDecimal] value
    #
    # @return [String]
    #
    # @api private
    def to_toml_float(value)
      return INF_POSITIVE if value.infinite? && value.positive?
      return INF_NEGATIVE if value.infinite? && value.negative?
      return NAN if value.nan?

      value.to_s
    end
  end
end
