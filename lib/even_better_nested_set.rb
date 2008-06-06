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
    
    def insert_node
      if self.parent
        self.parent.reload
        right_bound = self.parent.right
        self.left = right_bound
        self.right = right_bound + 1
      else
        last_root = self.class.find(:first, :order => 'right DESC', :conditions => { :parent_id => nil })
        self.left = last_root ? (last_root.right + 1) : 1
        self.right = last_root ? (last_root.right + 2) : 2
      end
    end
    
    def shift_in_node
      if self.parent
        # FIXME: there is a locking issue here, which probably fucks up badly with concurrent access
        old_parent_right = parent.right
        parent.reload
        raise "parent boundaries have changed" unless parent.right = old_parent_right
        #parent.right += 2
        
        self.class.base_class.update_all( "left = (left + 2)",  ["left >= ? AND NOT #{self.class.base_class.primary_key} = ?", self.left, self.id] )
        self.class.base_class.update_all( "right = (right + 2)",  ["right >= ? AND NOT #{self.class.base_class.primary_key} = ?", self.left, self.id] )

        #parent.save!
      end
    end
    
    def parent=(parent)
      @parent_changed = true
      self.cache_parent(parent)
      self.parent_id = parent ? parent.id : nil
    end
    
    def parent
      @parent ||= self.class.base_class.find_by_id(self.parent_id)
    end
    
    def children
      return @children if @children
      self.fetch_descendants
      @children
    end
    
    def patriarch
      @patriarch ||= self.class.base_class.find(:first, :conditions => ["left < ? AND right > ? AND parent_id IS NULL", self.left, self.right])
    end
    
    def descendants
      return @descendants if @descendants
      self.fetch_descendants
      @descendants
    end
    
    def nested_set
      self.children
    end
    
    def bounds
      self.left..self.right
    end
    
    def generation
      @generation ||= self.parent ? self.parent.children : self.class.base_class.roots.find(:all)
    end
    
    def siblings
      @siblings ||= (self.generation - [self])
    end
    
    def cache_parent(parent) #:nodoc:
      @parent = parent
    end
    
    def cache_child(child) #:nodoc:
      @children ||= []
      @children << child
    end
    
    protected
    
    def fetch_descendants
      @descendants = self.class.base_class.find_descendants(self)
      @children = self.class.base_class.sort_nodes_to_nested_set(@descendants)
    end
  
    def parent_changed?
      @parent_changed
    end
    
    def parent_cached?; @parent; end
    def children_cached?; @children; end
    
    def reset_cache
      @children, @parent = nil
    end
  end
  
  module NestedSetClassMethods
    
    def find_descendants(node)
      self.find(:all, :order => 'left ASC', :conditions => ["left > ? AND right < ?", node.left, node.right])
    end
    
    def nested_set(parent=nil)
      if parent
        sort_nodes_to_nested_set(self.find_descendants(parent))
      else
        sort_nodes_to_nested_set(self.find(:all, :order => 'left ASC'))
      end
    end
    
    def sort_nodes_to_nested_set(nodes)
      roots = []
      hashmap = {}
      for node in nodes
        # if the parent is not in the hashmap, parent will be nil, therefore node will be a root node
        # in that case
        parent = node.parent_id ? hashmap[node.parent_id] : nil

        if parent
          node.cache_parent(parent)
          parent.cache_child(node)
        else
          roots << node
        end
        
        hashmap[node.id] = node
      end
      return roots
    end
    
  end
  
  module ClassMethods
    
    def acts_as_nested_set
      validates_presence_of :left, :right
      validate :greater_left_attribute
      validate :odd_left_right_difference
      
      include NestedSetMethods
      extend NestedSetClassMethods
      named_scope :roots, :conditions => { :parent_id => nil}
      
      before_validation_on_create :insert_node
      after_create :shift_in_node
    end
    
  end
  
end

ActiveRecord::Base.send(:include, EvenBetterNestedSet)