class Member < Shortcut::Base
  include ActiveModel::Model
  attr_accessor :created_at, :created_without_invite, :disabled, :entity_type, :global_id, :group_ids, :id, :profile, :role, :state, :updated_at

  class << self
    def all
      ScrbClient.get("/members").map { |m| new(m) }.reject(&:disabled)
    end

    def find(uuid)
      new(ScrbClient.get("/members/#{uuid}"))
    end

    def fuzzy_find_by_name(name)
      all.find { |m| m.profile["name"].downcase.include?(name.downcase) || m.profile["mention_name"].downcase.include?(name.downcase) }
    end
  end

  def first_name
    (profile ? profile["name"] : "").split(" ").first
  end

  def last_name
    (profile ? profile["name"] : "").split(" ").last
  end
end
