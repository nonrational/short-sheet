require "csv"
require "awesome_print"
require "active_support/all"
require "hashie"
require "base64"

module Scrb
  class << self
    def shortcut
      ShortcutRuby::Shortcut.new(api_key)
    end

    def current_epics
      @current_epics ||= Epic.search("!is:archived !is:done")
    end

    def current_iteration
      @current_iteration ||= Iteration.find_current
    end

    def iterations
      @iterations ||= Iteration.all
    end

    def product_area_custom_field
      @product_area_custom_field ||= CustomField.all.find { |cf| cf.name.match(/product area/i) }
    end

    def priority_custom_field
      @priority_custom_field ||= CustomField.all.find { |cf| cf.name.match(/priority/i) }
    end

    def default_priority_custom_field
      @default_priority_custom_field ||= priority_custom_field.find_value_by_name(fetch_config!("default-priority-value"))
    end

    def ready_state_name
      @ready_for_name ||= fetch_config!("ready-state-name")
    end

    def workflow_name
      @workflow_name ||= fetch_config!("workflow-name")
    end

    def api_key
      @api_key ||= config["shortcut-api-token"] || ENV.fetch("SHORTCUT_API_TOKEN")
    end

    def config
      @config ||= begin
        if ENV["SCRB_CONFIG"].present?
          YAML.load(Base64.decode64(ENV["SCRB_CONFIG"]))
        else
          YAML.load_file("config.yml")
        end
      rescue Psych::SyntaxError
        raise "Uh oh! Invalid YAML in #{ENV["SCRB_CONFIG"].present? ? "SCRB_CONFIG" : "config.yml"}."
      end
    end

    def ready_state
      @ready_state ||= Workflow.default.workflow_states.find { |s| s.name.match(/#{ready_state_name}/i) }
    end

    def fetch_config!(key)
      raise "Uh oh! Missing config key '#{key}'." unless config[key].present?
      config[key]
    end
  end
end
