require "roo"
require "roo-xls"
require "tempfile"

class MsExcel::PlanningSheet
  def initialize(file_path)
    @file_path = file_path
    @spreadsheet = Roo::Spreadsheet.open(file_path)
  end

  def current_epic_initiatives
    initiatives.filter(&:epic?).reject do |i|
      if i.in_sync?
        puts "#{i} is in-sync. Skipping..."
      end

      i.in_sync?
    end
  end

  def download!
    puts "Fetching initiatives with epics..."
    initiatives

    puts "Updating sheet with #{current_epic_initiatives.count} initiatives..."
    current_epic_initiatives.each do |i|
      i.update_sheet
    end
  end

  def upload!
    push_sheet_order_to_shortcut!

    current_epic_initiatives.each do |i|
      i.update_epic
      puts i.epic.app_url
    end
  rescue => e
    binding.pry
  end

  def download_as_xlsx
    puts "Spreadsheet is already a local file: #{@file_path}"
  end

  def upload_interactive
    current_epic_initiatives.each do |i|
      puts "#{i} is out-of-sync by #{i.out_of_sync_details}"

      width = i.to_table_data.reduce(0) do |acc, row|
        row.reduce(acc) { |acc, v| [acc, v.to_s.size].max }
      end

      header = i.column_headers.map { |v| v.to_s.ljust(width) }.join(" | ")

      table_data = i.to_table_data.map do |row|
        row.map do |v|
          v.to_s.ljust(width + (/\p{Emoji}/.match?(v) ? 1 : 0))
        end.join(" | ")
      end.join("\n")

      puts header, table_data

      print "Which is more correct? row/epic/[skip]: "
      winner = $stdin.gets

      if /ro?w?/i.match?(winner)
        i.update_epic
      elsif /ep?i?c?/i.match?(winner)
        i.update_sheet
      end
    end
  rescue => e
    binding.pry
  end

  def organize_documents!
    initiatives.map do |i|
      puts i
      i.move_document_to_correct_drive_location
    end
  end

  def push_sheet_order_to_shortcut!
    initiatives.each_cons(2) do |before, after|
      puts "#{before.epic.name}(#{before.row_index}) is before #{after.epic.name}(#{after.row_index})"

      after.epic.update(after_id: before.epic.id).tap do |res|
        binding.pry unless res.success?
      end
    end

    :ok
  end

  def status_mismatch_initiatives
    initiatives.reject(&:status_match?)
  end

  def name_mismatch_initiatives
    initiatives.reject(&:name_match?)
  end

  def initiatives
    @initiatives ||= raw_initiatives.filter { |si| si.epic.present? }
  end

  def raw_initiatives
    @raw_initiatives ||= begin
      sheet.each_row_streaming(offset: 1).map.with_index do |row, idx|
        MsExcel::SheetInitiative.new(
          row_data: row,
          row_index: idx + 2,
          spreadsheet_id: spreadsheet_id,
          spreadsheet_range: spreadsheet_range,
          sheet_name: sheet_name
        )
      end
    end
  end

  def sheet
    @sheet ||= @spreadsheet.sheet(0)
  end

  def last_modified_at
    File.mtime(@file_path)
  end

  def to_s
    "MsExcel::PlanningSheet[#{@file_path}]"
  end

  def spreadsheet_id
    @file_path
  end

  def spreadsheet_range
    "Sheet1"
  end

  def sheet_name
    "Sheet1"
  end
end
