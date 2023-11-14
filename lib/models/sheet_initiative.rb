# An initiative represents a line-item in a planning spreadsheet and a corresponding shortcut epic.
class SheetInitiative
  include ActiveModel::Model
  attr_accessor :row_data, :row_index, :spreadsheet_id, :spreadsheet_range, :sheet_name

  # delegate the name function to row
  delegate :name, to: :row

  def pull
    pull_name_from_epic
    pull_target_dates_from_epic
    pull_status_from_epic
    pull_story_stats_from_epic
  end

  def push
    push_dates_and_status_to_epic
  end

  def move_document_to_correct_drive_location
    return false unless row.doctype_hyperlink.present?

    # get the document id from the row and move it to the correct folder based on its type.
    doctype_key = row.doctype&.downcase
    target_folder_id = Scrb.fetch_config!("planning-document-folders-by-doctype")[doctype_key]

    # break and return early if we don't have a target folder id
    if target_folder_id.nil?
      binding.pry
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

  #               _      _                  _
  #  _ __ _  _ __| |_   | |_ ___   ___ _ __(_)__
  # | '_ \ || (_-< ' \  |  _/ _ \ / -_) '_ \ / _|
  # | .__/\_,_/__/_||_|  \__\___/ \___| .__/_\__|
  # |_|                               |_|
  def push_dates_and_status_to_epic
    epic_workflow_state = EpicWorkflow.fetch.find_state_by_name(row.status)

    attrs = {deadline: row.target_date&.to_date&.iso8601}

    if epic_workflow_state.present? && epic_workflow_state.id != epic.epic_state_id
      attrs[:epic_state_id] = epic_workflow_state.id
    end

    result = epic.update(attrs)
    binding.pry unless result.success?
    @epic = Epic.new(result)
  end

  #            _ _    __                          _
  #  _ __ _  _| | |  / _|_ _ ___ _ __    ___ _ __(_)__
  # | '_ \ || | | | |  _| '_/ _ \ '  \  / -_) '_ \ / _|
  # | .__/\_,_|_|_| |_| |_| \___/_|_|_| \___| .__/_\__|
  # |_|                                     |_|

  def pull_dates_and_status_from_epic
    # TODO
  end

  def pull_target_dates_from_epic
    # TODO
  end

  def pull_status_from_epic
    # TODO: Spacing here might matter. Not sure if this is safe.
    row.update_cell_value(:status, epic.workflow_state.name)
  end

  def pull_name_from_epic
    raw_app_url = epic.app_url
    # append `?group_by=workflow_state_id` to all hyperlinked epics
    uri = URI.parse(raw_app_url)
    query_params = URI.decode_www_form(uri.query || "")
    query_params << ["group_by", "workflow_state_id"]
    uri.query = URI.encode_www_form(query_params)

    row.update_cell_value(:hyperlinked_name, "=HYPERLINK(\"#{uri}\", \"#{epic.name}\")")
  end

  def pull_story_stats_from_epic
    row.update_cell_value(:story_completion, epic.percent_complete)
  end

  def pull_participants_from_epic
    row.update_cell_value(:participants, epic.participant_members.map(&:first_name).join(", "))
  end

  #       _ _   _   _                     _
  #  __ _| | | | |_| |_  ___   _ _ ___ __| |_
  # / _` | | | |  _| ' \/ -_) | '_/ -_|_-<  _|
  # \__,_|_|_|  \__|_||_\___| |_| \___/__/\__|
  #

  def row
    @row ||= SheetRow.new(
      spreadsheet_id: spreadsheet_id,
      row_data: row_data,
      row_index: row_index,
      sheet_name: sheet_name
    )
  end

  def story?
    /story-/.match?(row.shortcut_id)
  end

  # does the sheet row have an epic listed?
  def epic?
    /epic-/.match?(row.shortcut_id)
  end

  def epic_id
    @epic_id ||= row.shortcut_id.split("-")[1].to_i if epic?
  end

  # does the sheet row list a valid shortcut epic?
  def epic
    @epic ||= Scrb.current_epics.find { |e| e.id == epic_id } if epic?
  end

  def drive_v3
    @drive_v3 ||= Google::Apis::DriveV3::DriveService.new.tap { |s| s.authorization = auth_client }
  end

  def auth_client
    @auth_client ||= GoogleCredentials.load!
  end

  def any_mismatch?
    !name_match? or !status_match? or !target_date_match?
  end

  def name_match?
    row.name.downcase == epic.name.downcase
  end

  def status_match?
    row.status.delete(" ") == epic.workflow_state.name.delete(" ")
  end

  def target_date_match?
    row.target_date == epic.target_date&.to_date
  end

  def to_s
    if epic.present?
      ["epic", epic.number, epic.name, row.target_date, epic.target_date&.to_date&.iso8601].join(",")
    elsif epic?
      ["epic", row.shortcut_id, "ERR!", nil, nil].join(",")
    elsif story?
      ["story", "ERR!", "ERR!", nil, nil].join(",")
    else
      ["ERR!", "ERR!", "ERR!", nil, nil].join(",")
    end
  end
end
