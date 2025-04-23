# Rakefile
require "bundler/setup"
Bundler.require
require "active_support"
require "active_model"
require "shortcut_ruby"
require "dotenv/load"
require "awesome_print"

def load_paths!
  path = File.expand_path("..", __FILE__)
  files = Dir.glob("#{path}/**/*.rb").sort
  files.each do |f|
    # puts f
    load f
  end
end

load_paths!

namespace :planning do
  desc "Fetch information from shortcut and update the sheet with it"
  task :update_sheet do
    GoogleWorkspace::PlanningSheet.new.download!
  end

  desc "Interactively review any out-of-sync initiatives and choose whether to update shortcut or the sheet"
  task :review do
    GoogleWorkspace::PlanningSheet.new.upload_interactive
  end

  desc "Sort epics by sheet order and ready stories by priority"
  task :prioritize_shortcut do
    puts "Sorting epics by planning sheet order..."
    # ensure that the priority order reflected in the planning sheet is respected
    GoogleWorkspace::PlanningSheet.new.push_sheet_order_to_shortcut!
    # then sort all the "ready" cards in the current iteration
    puts "Sorting ready stories by priority..."
    IterationReadySort.new.run
  end
end

namespace :monthly_chores do
  desc "Create the next monthly chores epic"
  task :create_current do
    GoogleWorkspace::NextMonthlyChoresSheet.new(as_of: 1.month.ago).tap do |sheet|
      print "Creating #{sheet.next_epic_name}. Proceed? yes/[no]: "
      result = $stdin.gets
      sheet.create_next_epic if /ye?s?/i.match?(result)
    end
  end

  desc "Create the next monthly chores epic"
  task :create_next do
    GoogleWorkspace::NextMonthlyChoresSheet.new.tap do |sheet|
      print "Creating #{sheet.next_epic_name}. Proceed? yes/[no]: "
      result = $stdin.gets
      sheet.create_next_epic if /ye?s?/i.match?(result)
    end
  end
end

namespace :shortcut do
  namespace :project_sync do
    desc "Ensure that all stories with a project have the correct product area set"
    task :run do
      BulkProjectSync.new.run
    end
  end

  namespace :iteration do
    desc "Create the next iteration"
    task :create_next do
      curr = Iteration.find_futuremost || Iteration.find_current
      next_iteration = curr.build_next
      puts "Creating #{next_iteration.name} from #{next_iteration.start_date} to #{next_iteration.end_date}"
      curr.build_next.save
    end
  end
end

namespace :config do
  desc "Export the config.yml file as a base64 encoded string"
  task :export do
    config = Base64.encode64(File.read("config.yml")).tr("\n", "")
    puts "export SCRB_CONFIG='#{config}'"
  end

  desc "Check config is valid"
  task :check do
    expected_keys = YAML.load_file("config.yml.example").keys.to_set
    actual_keys = Scrb.config.keys.to_set

    raise "missing keys: #{(expected_keys - actual_keys).to_a.join(",")}" unless actual_keys.superset?(expected_keys)
    puts "Looks good!"
  end
end
