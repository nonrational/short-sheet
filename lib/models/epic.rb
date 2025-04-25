require "active_support/core_ext/time/zones"

class Epic
  include ActiveModel::Model

  class << self
    def all
      ScrbClient.get("/epics").map { |e| Epic.new(e) }
    end

    def in_progress
      all.select(&:in_progress?)
    end

    def find(id)
      result = ScrbClient.get("/epics/#{id}")
      return nil unless result.ok?
      Epic.new(result)
    end

    def find_or_create_by(attrs)
      search(attrs[:name]).find { |e| e.name == attrs[:name] } || create(attrs)
    end

    def search(query)
      EpicSearch.new(query: query).tap(&:fetch_all).epics
    end

    # https://developer.shortcut.com/api/rest/v3#Create-Epic

    def create(attrs)
      result = ScrbClient.post("/epics", body: attrs.to_json)
      binding.pry unless result.created?
      Epic.new(result)
    end
  end

  attr_accessor :app_url, :archived, :description, :comments, :started, :entity_type, :labels, :mention_ids,
    :member_mention_ids, :associated_groups, :project_ids, :stories_without_projects, :completed_at_override,
    :productboard_plugin_id, :started_at, :completed_at, :name, :global_id, :completed, :productboard_url, :state,
    :milestone_id, :requested_by_id, :epic_state_id, :label_ids, :started_at_override, :group_id, :group_ids, :updated_at,
    :group_mention_ids, :productboard_id, :follower_ids, :owner_ids, :external_id, :id, :position, :productboard_name,
    :stats, :created_at, :objective_ids, :deadline, :planned_start_date

  def update(attrs)
    ScrbClient.put("/epics/#{id}", body: attrs.to_json)
  end

  def assign_to_group(group_name)
    group_id = Group.find_by_name(group_name).id

    return "Group not found" if group_id.nil?
    return "Group already assigned" if self.group_id == group_id

    result = update(group_ids: [group_id])

    binding.pry unless result.ok?

    :ok
  end

  def planned_starts_at
    DateTime.parse(planned_start_date.to_s).in_time_zone("America/New_York") unless planned_start_date.nil?
  end

  def planned_starts_at=(at)
    self.planned_start_date = at.iso8601 unless at.nil?
  end

  def planned_ends_at
    DateTime.parse(target_date.to_s).in_time_zone("America/New_York") unless target_date.nil?
  end

  def planned_ends_at=(at)
    self.target_date = at.iso8601 unless at.nil?
  end

  alias_method :archived?, :archived
  alias_method :started?, :started
  alias_method :completed?, :completed
  alias_method :done?, :completed

  alias_method :target_date, :deadline
  alias_method :target_date=, :deadline=

  def owner_members
    @owner_members ||= owner_ids.map { |uuid| Member.find(uuid) }
  end

  def participant_members
    @participant_members ||= stories.flat_map(&:owner_members).uniq(&:id)
  end

  def story_completion
    [stats["num_stories_done"], "/", stats["num_stories_total"]].join("")
  end

  def percent_complete
    return "0%" unless stats["num_stories_total"] > 0
    ((stats["num_stories_done"].to_f / stats["num_stories_total"].to_f) * 100).round.to_s + "%"
  end

  def stories
    @stories ||= begin
      ScrbClient.get("/epics/#{id}/stories").map { |s| Story.new(s) }
    end
  end

  def roadmap?
    labels.any? { |l| l["name"].match(/roadmap\z/i) }
  end

  def workflow_state
    @workflow_states ||= EpicWorkflow.fetch.epic_states.find { |es| es.id == epic_state_id }
  end

  def planned_start_iteration
    # find iteration by planned_start_date
    return nil if planned_start_date.nil?
    Scrb.iterations.sort_by(&:start_date).reverse!.find { |i| (i.start_date...i.end_date).cover?(planned_start_date) }
  end

  def target_iteration
    # find iteration by deadline
    return nil if deadline.nil?
    Scrb.iterations.sort_by(&:start_date).reverse!.find { |i| (i.start_date...i.end_date).cover?(deadline) }
  end

  def stories_in_current_iteration?
    stories.any? { |s| s.iteration_id == Scrb.current_iteration.id }
  end

  def in_progress?
    !archived? && started? && !completed?
  end
end
