require "google/apis/sheets_v4"

class GoogleWorkspace::NextMonthlyChoresSheet
  include ActiveModel::Model

  # By default, this will create chores for the _next_ month,
  # so be sure to backdate this if you're running this on the first of the month.
  attr_writer :as_of

  def next_epic_name
    epic_attrs[:name]
  end

  def create_next_epic
    @epic = Epic.find_or_create_by(epic_attrs)
    puts "#{@epic.name} - #{@epic.app_url}"
    puts "#{first_half_iteration.name} - #{first_half_iteration.app_url}"

    print "Create stories? yes/[no]: "

    result = $stdin.gets
    return unless /ye?s?/i.match?(result)

    story_row_data.each do |story_attrs|
      puts "Creating Story: #{story_attrs[:name]}"
      Story.create(story_attrs)
      # ap story_attrs
    rescue => e
      binding.pry
    end
  end

  def as_of
    @as_of ||= Date.today
  end

  def epic
    @epic ||= Epic.search(epic_attrs[:name]).find { |e| e.name == epic_attrs[:name] }
  end

  def starts_at
    @starts_at ||= as_of.at_beginning_of_month.next_month.to_datetime.at_noon
  end

  def epic_attrs
    {
      name: "#{starts_at.strftime("%B %Y")} Tech Chores",
      description: "Monthly Tech Chores :tada:",
      group_ids: [product_group_id],
      # TODO: Generalize this objective ID
      objective_ids: [14005], # this is the tech debt / misc objective,
      planned_start_date: starts_at.beginning_of_month.iso8601,
      deadline: starts_at.end_of_month.iso8601
    }
  end

  # https://developer.shortcut.com/api/rest/v3#Create-Story
  def story_row_data
    # Ignore rows that are "off-cycle" for this month's epic.
    sheet.data[0].row_data.drop(1).filter { |r| include_row_this_month?(r) }.map do |row|
      {
        name: value_at_col(row, :A).formatted_value,
        story_type: value_at_col(row, :B).formatted_value,
        description: description_with_attribution(value_at_col(row, :C).formatted_value),
        group_id: product_group_id,
        epic_id: epic&.id,
        workflow_state_id: ready_workflow_state_id,
        iteration_id: first_half_iteration&.id,
        custom_fields: [
          {
            field_id: TechnicalArea.field.id,
            value_id: TechnicalArea.all.find { |ta| ta.name == value_at_col(row, :J).formatted_value }&.id
          },
          {
            field_id: Priority.field.id,
            value_id: Priority.default.id
          },
          {
            field_id: PartnerImpact.field.id,
            value_id: PartnerImpact.find_by_value("Indirect").id
          }
        ]
      }
    end
  end

  # For example, A chore scheduled for every 3 months will be added in Jan, Apr, Jul, and Oct.
  def include_row_this_month?(row)
    return false if value_at_col(row, :A).formatted_value.blank?

    each_month = value_at_col(row, :K).formatted_value&.to_i

    (each_month.nil? || each_month == 1 || (starts_at.month - 1) % each_month == 0).tap do |result|
      puts "Excluding '#{value_at_col(row, :A).formatted_value}' this month" unless result
    end
  end

  def value_at_col(row, col)
    index = col.to_s.chars.reverse.each_with_index.reduce(0) do |sum, (char, index)|
      sum + (char.ord - 64) * (26**index)
    end - 1

    row.values[index]
  end

  def epic_description
    File.read(File.expand_path("../../../templates/monthly-tech-chores.md", __FILE__)) || "Monthly Tech Chores :tada:"
  end

  def first_half_iteration
    @first_half_iteration ||= Iteration.find_by_name([starts_at.strftime("%B"), "H1", starts_at.strftime("%Y")].join(" "))
  end

  def description_with_attribution(desc)
    (desc || "") + "\n\n\n[📝 Edit Template](https://docs.google.com/spreadsheets/d/#{spreadsheet_id}/edit)"
  end

  def drive_v3
    @drive_v3 ||= Google::Apis::DriveV3::DriveService.new.tap { |s| s.authorization = auth_client }
  end

  def sheets_v4
    @sheets_v4 ||= Google::Apis::SheetsV4::SheetsService.new.tap { |s| s.authorization = auth_client }
  end

  def sheet
    @sheet ||= begin
      spreadsheet.sheets.first
    end
  end

  def spreadsheet
    @spreadsheet ||= sheets_v4.get_spreadsheet(spreadsheet_id, include_grid_data: true, ranges: [spreadsheet_range])
  end

  def ready_workflow_state_id
    @ready_workflow_state_id ||= Workflow.default.workflow_states.find { |s| s.name =~ /Ready/ }.id
  end

  def product_group_id
    @product_group_id ||= Group.all.find { |g| g.name =~ /Product/ }.id
  end

  def objective_ids
    [Scrb.fetch_config!("technical-objective-id")]
  end

  def spreadsheet_id
    Scrb.fetch_config!("chores-epic-sheet-id")
  end

  def spreadsheet_range
    Scrb.fetch_config!("chores-epic-sheet-range")
  end

  def auth_client
    @auth_client ||= GoogleCredentials.load!
  end
end
