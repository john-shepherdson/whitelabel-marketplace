# frozen_string_literal: true

class ApplicationService
  def self.call(...)
    new(...).call
  end

  def initialize
    raise "Should be implemented in descendent class"
  end

  def call
    raise "Should be implemented in descendent class"
  end
end
