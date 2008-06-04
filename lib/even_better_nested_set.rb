path = File.join(File.dirname(__FILE__), 'even_better_nested_set/')

require path + 'child_association_proxy'

module EvenBetterNestedSet
  
  def self.included(base)
    super
    base.extend ClassMethods
  end
  
  def greater_left_attribute
    if self.left and self.right and self.left > self.right
      self.errors.add(:left, "Left must not be greater than right!")
    end
  end
  
  def odd_left_right_difference
    if self.left and self.right and ((self.right - self.left) % 2).zero?
      self.errors.add(:left, "The difference between the left and right bounds must be an odd number!")
    end
  end
  
  module NestedSetMethods
    
    def setup_root_node
      unless self.parent_id?
        last_root = self.class.find(:first, :order => 'right DESC', :conditions => { :parent_id => nil })
        self.left = last_root ? (last_root.right + 1) : 1
        self.right = last_root ? (last_root.right + 2) : 2
      end
    end
    
    def parent
      self.class.find(self.parent_id)
    end
    
    def bounds
      self.left..self.right
    end
  end
  
  module ClassMethods
    
    def acts_as_nested_set
      validates_presence_of :left, :right
      validate :greater_left_attribute
      validate :odd_left_right_difference
      
      include NestedSetMethods
      
      before_validation_on_create :setup_root_node
    end
    
  end
  
end

ActiveRecord::Base.send(:include, EvenBetterNestedSet)