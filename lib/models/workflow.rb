class Workflow < Shortcut::Base
  attr_accessor :description, :entity_type, :project_ids, :states, :name, :updated_at, :auto_assign_owner, :id, :team_id, :created_at, :default_state_id

  class << self
    def all
      ScrbClient.get("/workflows").map { |w| Workflow.new(w) }
    end

    def find(id)
      Workflow.new(ScrbClient.get("/workflows/#{id}"))
    end

    def default
      all.find { |w| w.name == Scrb.fetch_config!("workflow-name") }
    end
  end

  def workflow_states
    @workflow_states ||= states.map { |s| WorkflowState.new(s) }
  end

  class WorkflowState
    include ActiveModel::Model
    attr_accessor :description, :entity_type, :verb, :name, :global_id, :num_stories, :type, :updated_at, :id, :num_story_templates, :position, :created_at

    def name_ilike?(pattern)
      name.match(/#{pattern}/i)
    end
  end
end
