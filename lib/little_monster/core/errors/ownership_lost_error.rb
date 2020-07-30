module LittleMonster::Core
  class OwnershipLostError < StandardError
    def initialize
      super("job ownership lost to another worker")
    end
  end
end
