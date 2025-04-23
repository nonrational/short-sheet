class GoogleWorkspace::SheetRow
  include ActiveModel::Model
  attr_accessor :spreadsheet_id, :row_data, :row_index, :sheet_name

  # TODO: Move this config?
  # A	    B	    C	  D	        E	    F	      G       H	    I	      J	    K	  L	           M
  # index	Name	Doc	Shortcut	Owner	Urgency	Status	Begin	Target	Start	End	Last Mention Notes

  def batch_update_values(hash)
    list_of_data_ranges = hash.map do |k, v|
      Google::Apis::SheetsV4::ValueRange.new(
        range: cell_range_by_column_name(k),
        values: [[v]]
      )
    end

    ap list_of_data_ranges

    # https://googleapis.dev/ruby/google-api-client/latest/Google/Apis/SheetsV4/BatchUpdateValuesRequest.html
    batch_request = Google::Apis::SheetsV4::BatchUpdateValuesRequest.new(
      data: list_of_data_ranges,
      # The values will be parsed as if the user typed them into the UI.
      # Numbers will stay as numbers, but strings may be converted to numbers, dates, etc.
      # following the same rules that are applied when entering text into a cell
      # via the Google Sheets UI.
      value_input_option: "USER_ENTERED"
    )

    # https://googleapis.dev/ruby/google-api-client/latest/Google/Apis/SheetsV4/SheetsService.html#batch_update_values-instance_method
    sheets_v4.batch_update_values(spreadsheet_id, batch_request, options: {authorization: auth_client}) do |result, err|
      binding.pry if err
      result
    end
  end

  def update_value(name, user_entered_value)
    batch_update_values(name => user_entered_value)
  end

  def sheets_v4
    @sheets_v4 ||= Google::Apis::SheetsV4::SheetsService.new
  end

  def auth_client
    @auth_client ||= GoogleCredentials.load!
  end

  def cell_range_by_column_index(col_alpha)
    [sheet_name, "!", col_alpha.to_s.upcase, row_index].join
  end

  def cell_range_by_column_name(col_name)
    cell_range_by_column_index(column_map[col_name.to_sym])
  end

  def number
    fetch(:number).formatted_value&.to_i
  end

  def name
    fetch(:hyperlinked_name).formatted_value
  end

  def name_hyperlink
    fetch(:hyperlinked_name).hyperlink
  end

  def doctype
    fetch(:hyperlinked_doctype).formatted_value
  end

  def doctype_hyperlink
    fetch(:hyperlinked_doctype).hyperlink
  end

  def story_completion
    fetch(:story_completion).formatted_value
  end

  def document_id
    doctype_hyperlink.reverse.split("/")[1].reverse
  end

  def epic_id
    name_hyperlink&.match(/epic\/(\d+)/)&.captures&.first&.to_i
  end

  def story_id
    name_hyperlink&.match(/story\/(\d+)/)&.captures&.first&.to_i
  end

  # this could be story-xxxx or epic-xxxx
  def shortcut_id
    fetch(:shortcut_id).formatted_value
  end

  def owner_name
    fetch(:owner_name).formatted_value
  end

  def urgency
    fetch(:urgency).formatted_value
  end

  def status
    fetch(:status).formatted_value
  end

  def start_date
    @start_date ||= begin
      Date.iso8601(fetch(:start_date).formatted_value).in_time_zone("America/New_York")
    rescue
      nil
    end
  end

  def target_date
    @target_date ||= begin
      Date.iso8601(fetch(:target_date).formatted_value).in_time_zone("America/New_York")
    rescue
      nil
    end
  end

  def to_s
    "#{sheet_name}:#{row_index}"
  end

  private

  def fetch(col_name)
    col_sym = column_map[col_name.to_sym]
    raise "#{column} not found" if col_sym.nil?
    value_at(col_sym)
  end

  def value_at(col_sym)
    if row_data.values.nil?
      # puts "#{col_sym} of #{self} is nil"
      return EmptyValue.new
    end

    column = col_sym.to_s.upcase
    cell_value = row_data.values[column.chars.reduce(0) { |acc, char| acc * 26 + (char.ord - "A".ord) }]

    cell_value || EmptyValue.new
  end

  class EmptyValue
    def formatted_value
      nil
    end

    def hyperlink
      nil
    end
  end

  def column_map
    # todo: build this with a zip.
    @column_map ||= {
      number: :A,
      hyperlinked_name: :B,
      hyperlinked_doctype: :C,
      shortcut_id: :D,
      owner_name: :E,
      urgency: :F,
      status: :G,
      start_iteration: :H,
      target_iteration: :I,
      start_date: :J,
      target_date: :K,
      participants: :L,
      last_mention: :M,
      story_completion: :N,
      notes: :O
    }
  end
end
