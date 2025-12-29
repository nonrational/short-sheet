require "httparty"

class ScrbClient
  include HTTParty

  base_uri "https://api.app.shortcut.com/api/v3"
  headers({
    "Content-Type": "application/json",
    "Shortcut-Token": Scrb.api_key
  })

  def self.get(*args)
    # puts "Default options: #{default_options}"
    super
  end

  def self.post(*args)
    # puts "Default options: #{default_options}"
    super
  end

  def self.put(*args)
    # puts "Default options: #{default_options}"
    super
  end

  def self.delete(*args)
    # puts "Default options: #{default_options}"
    super
  end
end
