# require "spreadsheet"

# Represents a single row in an Excel worksheet.
class MsExcel::SheetRow
  attr_accessor :workbook_path, :row_data, :row_index, :worksheet_name

  def initialize(workbook_path:, row_data:, row_index:, worksheet_name:)
    @workbook_path = workbook_path
    @row_data = row_data
    @row_index = row_index
    @worksheet_name = worksheet_name
  end

  # Updates the values in the row with the given attributes
  def batch_update_values(attrs)
    workbook = RubyXL::Parser.parse(workbook_path)
    worksheet = workbook[worksheet_name]

    attrs.each do |key, value|
      column_index = column_mapping[key]
      next unless column_index

      worksheet.add_cell(row_index, column_index, value)
    end

    workbook.write(workbook_path)
  end

  # Returns the value of a specific column in the row
  def [](key)
    column_index = column_mapping[key]
    return nil unless column_index

    row_data[column_index]
  end

  # Maps attribute keys to column indices (zero-based)
  def column_mapping
    [
      :number,                 # A
      :hyperlinked_name,       # B
      :hyperlinked_doctype,    # C
      :shortcut_id,            # D
      :owner_name,             # E
      :urgency,                # F
      :status,                 # G
      :start_iteration,        # H
      :target_iteration,       # I
      :start_date,             # J
      :target_date,            # K
      :participants,           # L
      :story_completion,       # M
      :notes                   # N
    ].each_with_index.each_with_object({}) do |(key, index), hash|
      hash[key] = index
    end
  end

  def name_hyperlink
    self[:hyperlinked_name]
      &.formula
      &.match(/HYPERLINK\("([^"]+)"/)
      &.captures
      &.first
  end

  def epic_id
    name_hyperlink&.match(/epic\/(\d+)/)&.captures&.first&.to_i
  end

  def story_id
    name_hyperlink&.match(/story\/(\d+)/)&.captures&.first&.to_i
  end

  def number
    self[:number].formatted_value&.to_i
  end

  def name
    self[:hyperlinked_name].formatted_value
  end

  def doctype
    self[:hyperlinked_doctype].formatted_value
  end

  def doctype_hyperlink
    puts "[NOT SUPPORTED] MsExcel::SheetRow#doctype_hyperlink is not supported."
    nil
  end

  def story_completion
    self[:story_completion].formatted_value
  end

  def document_id
    puts "[NOT SUPPORTED] MsExcel::SheetRow#document_id is not supported."
    nil
  end

  # this could be story-xxxx or epic-xxxx
  def shortcut_id
    self[:shortcut_id].formatted_value
  end

  def owner_name
    self[:owner_name].formatted_value
  end

  def urgency
    self[:urgency].formatted_value
  end

  def status
    self[:status].formatted_value
  end

  def start_date
    @start_date ||= begin
      self[:start_date].value
    rescue
      nil
    end
  end

  def target_date
    @target_date ||= begin
      self[:target_date].value
    rescue
      nil
    end
  end

  def to_s
    "#{worksheet_name}:#{row_index}"
  end
end
