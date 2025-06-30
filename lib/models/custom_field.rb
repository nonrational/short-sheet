class CustomField < Shortcut::Base
  attr_accessor :description, :entity_type, :name, :fixed_position, :updated_at, :id, :values,
    :field_type, :position, :canonical_name, :enabled, :created_at, :story_types, :icon_set_identifier

  class << self
    def all
      ScrbClient.get("/custom-fields").map { |r| CustomField.new(r) }
    end

    def remote_attributes
      fields = Set[]
      ScrbClient.get("/custom-fields").each { |cf| fields.merge(cf.keys) }
      fields.map(&:to_sym)
    end

    def enabled
      all.filter(&:enabled)
    end

    def find_field(name_pattern)
      all.find { |f| f.name.match(/#{name_pattern}/i) }
    end
  end

  class Value
    include ActiveModel::Model
    attr_accessor :id, :value, :position, :color_key, :enabled, :entity_type
    alias_method :name, :value

    def canonical_name
      value.downcase.dasherize
    end
  end

  def enabled_values
    @enabled_values ||= values.map { |v| Value.new(v) }.filter(&:enabled)
  end

  def find_value_by_id(value_id)
    enabled_values.find { |v| v.id == value_id }
  end

  def find_value_by_name(value_pattern)
    enabled_values.find { |v| v.value.match(/#{value_pattern}/i) }
  end
end
