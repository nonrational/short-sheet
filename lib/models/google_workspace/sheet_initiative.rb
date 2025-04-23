# An initiative represents a line-item in a planning
# sheet and a corresponding shortcut epic (or story).
class GoogleWorkspace::SheetInitiative
  include ActiveModel::Model
  attr_accessor :row_data, :row_index, :spreadsheet_id, :spreadsheet_range, :sheet_name

  # delegate the name function to row
  delegate :epic_id, :name, to: :row

  # Is this initiative represented by a shortcut epic?
  def epic?
    epic.present?
  end

  # Is this initiative represented by a shortcut story?
  def story?
    story.present?
  end

  def update_sheet
    attrs = {
      shortcut_id: shortcut_id,
      hyperlinked_name: hyperlinked_name,
      story_completion: stats_summary,
      participants: participants
    }

    # TODO: Figure out how to translate status for stories?
    attrs[:status] = sheet_status if epic?

    ap(attrs)

    row.batch_update_values(attrs)
  end

  def update_epic
    push_dates_and_status_to_epic
  end

  def move_document_to_correct_drive_location
    return false unless row.doctype_hyperlink.present?

    # get the document id from the row and move it to the correct folder based on its type.
    doctype_key = row.doctype&.downcase
    target_folder_id = Scrb.fetch_config!("planning-document-folders-by-doctype")[doctype_key]

    # break and return early if we don't have a target folder id
    if target_folder_id.nil?
      # binding.pry
      return false
    end

    file = drive_v3.get_file(row.document_id, fields: "parents", supports_all_drives: true)
    previous_parents = file.parents.join(",")

    return :ok if previous_parents == target_folder_id

    puts "Moving #{row.document_id} from #{previous_parents} to #{target_folder_id}..."

    drive_v3.update_file(
      row.document_id,
      add_parents: target_folder_id,
      remove_parents: previous_parents,
      fields: "id,parents",
      supports_all_drives: true
    )
  end

  def push_dates_and_status_to_epic
    epic_workflow_state = EpicWorkflow.fetch.find_state_by_name(row.status)
    product_group_id = Group.find_by_name("Product").id
    owner = Member.fuzzy_find_by_name(row.owner_name) unless row.owner_name == "None"

    # TODO: add quarterly labels?

    attrs = {}

    attrs[:planned_start_date] = row.start_date.iso8601 if row.start_date.present?
    attrs[:deadline] = row.target_date.iso8601 if row.target_date.present?
    attrs[:group_id] = product_group_id if product_group_id.present? && epic.group_id != product_group_id

    if owner.present? && owner.id != epic.owner_ids.first
      attrs[:owner_ids] = [owner.id]
    end

    if epic_workflow_state.present? && epic_workflow_state.id != epic.epic_state_id
      attrs[:epic_state_id] = epic_workflow_state.id
    end

    result = epic.update(attrs)

    binding.pry unless result.success?

    @epic = Epic.new(result)
  end

  def sheet_status
    return "✔️ Done" if epic.workflow_state.name == "Done"

    epic.workflow_state.name
  end

  def hyperlinked_name
    return "=HYPERLINK(\"#{epic_uri_with_group_by}\", \"#{safe_name}\")" if epic?
    return "=HYPERLINK(\"#{story.app_url}\", \"#{safe_name}\")" if story?

    row.name
  end

  def shortcut_id
    return "epic-#{epic.id}" if epic?
    return "story-#{story.id}" if story?

    "N/A"
  end

  def epic_uri_with_group_by
    epic_uri = URI.parse(epic.app_url)

    query_params = URI.decode_www_form(epic_uri.query || "")
    query_params << ["group_by", "workflow_state_id"]

    epic_uri.query = URI.encode_www_form(query_params)
    epic_uri
  end

  def safe_name
    # translate double quotes to single quotes to avoid breaking the google sheet formula
    (epic || story || row).name.tr('"', "'")
  end

  def stats_summary
    return "-" if story?

    "#{epic.percent_complete} – #{epic.stats["num_stories_started"]} in-flight, #{epic.stats["num_stories_unstarted"]} remaining"
  end

  def participants
    return epic.participant_members.map(&:first_name).join(", ") if epic?
    return story.owner_members.map(&:first_name).join(", ") if story?
    "-"
  end

  #       _ _   _   _                     _
  #  __ _| | | | |_| |_  ___   _ _ ___ __| |_
  # / _` | | | |  _| ' \/ -_) | '_/ -_|_-<  _|
  # \__,_|_|_|  \__|_||_\___| |_| \___/__/\__|
  #

  def to_s
    "[#{row_index}] #{row.name}"
  end

  def row
    @row ||= GoogleWorkspace::SheetRow.new(
      spreadsheet_id: spreadsheet_id,
      row_data: row_data,
      row_index: row_index,
      sheet_name: sheet_name
    )
  end

  # does the sheet row list a valid shortcut epic?
  def epic
    @epic ||= Scrb.recent_epics.find { |e| e.id == epic_id } if epic_id.present?
  end

  def story
    @story ||= Story.find_by_id(row.story_id) if row.story_id.present?
  end

  def drive_v3
    @drive_v3 ||= Google::Apis::DriveV3::DriveService.new.tap { |s| s.authorization = auth_client }
  end

  def auth_client
    @auth_client ||= GoogleCredentials.load!
  end

  def in_sync?
    in_sync_details.values.all?
  end

  def out_of_sync_details
    out_of_sync = []
    in_sync_details.each { |k, v| out_of_sync << k unless v }
    out_of_sync
  end

  def in_sync_details
    {
      name: name_match?,
      status: status_match?,
      start_date: start_date_match?,
      target_date: target_date_match?,
      story_stats: story_stats_match?
    }
  end

  def column_headers(width = 30)
    [" ", "Row", "Epic"]
  end

  def to_table_data(width = 30)
    [
      ["URL", "", epic.app_url],
      ["Name", row.name, epic.name],
      ["Status", row.status, epic.workflow_state.name],
      ["Start", row.start_date&.to_date&.iso8601, epic.planned_starts_at&.to_date&.iso8601],
      ["Target", row.target_date&.to_date&.iso8601, epic.planned_ends_at&.to_date&.iso8601]
    ]
  end

  def story_stats_match?
    return true if story?
    row.story_completion == stats_summary
  end

  def name_match?
    row.name == safe_name
  end

  def status_match?
    row.status == sheet_status
  end

  def start_date_match?
    row.start_date == epic.planned_starts_at
  end

  def target_date_match?
    row.target_date == epic.planned_ends_at
  end
end
