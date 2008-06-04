module EvenBetterNestedSet
  
  
  class ChildAssociationProxy
  
    attr_accessor :children, :precached_children, :parent
  
    def initialize(parent)
      self.parent = parent
    end
    
    def create!(attributes = {})
      #self.parent.class.new(attributes.merge(:))
      
    end
  
  end
  
end