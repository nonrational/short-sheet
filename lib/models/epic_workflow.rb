class EpicWorkflow < Shortcut::Base
  attr_accessor :entity_type, :id, :created_at, :updated_at, :default_epic_state_id, :epic_states

  class << self
    def fetch
      @workflow ||= begin
        workflow = new(ScrbClient.get("/epic-workflow"))
        workflow.epic_states = workflow.epic_states.map { |es| EpicWorkflowState.new(es) }
        workflow
      end
    end
  end

  def find_state_by_name(name)
    epic_states.find { |s| s.name.downcase.gsub(/[^a-z]/i, "") == name.downcase.gsub(/[^a-z]/i, "") }
  end

  def find_state_like(name_pattern)
    epic_states.find { |s| s.name.match(name_pattern) }
  end

  class EpicWorkflowState
    include ActiveModel::Model
    attr_accessor :description, :entity_type, :name, :global_id, :type, :updated_at, :id, :position, :created_at
  end
end
