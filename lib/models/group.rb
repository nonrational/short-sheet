class Group
  include ActiveModel::Model

  attr_accessor :app_url, :description, :archived, :entity_type, :color, :num_stories_started,
    :mention_name, :name, :global_id, :color_key, :num_stories, :num_epics_started,
    :num_stories_backlog, :id, :display_icon, :member_ids, :workflow_ids

  class << self
    def all
      ScrbClient.get("/groups").map { |w| Group.new(w) }
    end

    def find(id)
      Group.new(ScrbClient.get("/groups/#{id}"))
    end

    def find_by_name(name)
      all.find { |t| t.name == name }
    end
  end
end
