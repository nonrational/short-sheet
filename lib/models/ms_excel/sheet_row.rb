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
    {
      shortcut_id: 0,
      hyperlinked_name: 1,
      story_completion: 2,
      participants: 3,
      status: 4,
      name: 5,
      epic_id: 6,
      story_id: 7,
      start_date: 8,
      target_date: 9,
      doctype: 10,
      doctype_hyperlink: 11,
      document_path: 12
    }
  end

  # Example attributes for the row
  def name
    self[:name]
  end

  def epic_id
    self[:epic_id]
  end

  def story_id
    self[:story_id]
  end

  def status
    self[:status]
  end

  def start_date
    self[:start_date]
  end

  def target_date
    self[:target_date]
  end

  def story_completion
    self[:story_completion]
  end

  def doctype
    self[:doctype]
  end

  def doctype_hyperlink
    self[:doctype_hyperlink]
  end

  def document_path
    self[:document_path]
  end
end
