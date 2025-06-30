class Shortcut::Base
  include ActiveModel::Model

  def method_missing(method, *args, &block)
    if method.to_s.end_with?("=")
      attribute = method.to_s.chomp("=")
      self.class.send(:attr_accessor, attribute) unless respond_to?(attribute)
      warn "Warning: #{self.class} attribute '#{attribute}' is not explicitly defined, please define it."
      send(method, *args)
    else
      super
    end
  end

  def respond_to_missing?(method, include_private = false)
    method.to_s.end_with?("=") || super
  end
end
