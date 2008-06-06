path = File.join(File.dirname(__FILE__), 'even_better_nested_set/')

require path + 'child_association_proxy'

module EvenBetterNestedSet
  
  def self.included(base)
    super
    base.extend ClassMethods
  end
  
  module NestedSetMethods
    
    def parent=(new_parent)
      @old_parent = self.parent
      self.cache_parent(new_parent)
      self.parent_id = new_parent ? parent.id : nil
    end
    
    def parent
      @parent ||= self.class.base_class.find_by_id(self.parent_id)
    end
    
    def children
      return @children if @children
      @descendants, @children = self.fetch_descendants
      @children
    end
    
    def patriarch
      @patriarch ||= self.class.base_class.find(:first, :conditions => ["left < ? AND right > ? AND parent_id IS NULL", self.left, self.right])
    end
    
    def descendants
      return @descendants if @descendants
      @descendants, @children = self.fetch_descendants
      @descendants
    end
    
    def nested_set
      self.children
    end
    
    def generation
      @generation ||= self.parent ? self.parent.nested_set : self.class.base_class.nested_set
    end
    
    def siblings
      @siblings ||= (self.generation - [self])
    end
    
    def bounds
      self.left..self.right
    end
    
    def cache_parent(parent) #:nodoc:
      @parent = parent
    end
    
    def cache_child(child) #:nodoc:
      @children ||= []
      @children << child
    end
    
    protected
    
    def remove_node
      difference = (self.right - self.left + 1)
      self.class.base_class.delete_all(['left > ? AND right < ?', self.left, self.right])
      
      self.class.base_class.update_all( "left = (left - #{difference})",  ["left >= ?", self.right] )
      self.class.base_class.update_all( "right = (right - #{difference})",  ["right >= ?", self.right] )
    end
    
    def append_node
      transaction do
        if self.parent
          self.parent.reload
          right_bound = self.parent.right
          self.left = right_bound
          self.right = right_bound + 1
        
          self.class.base_class.update_all( "left = (left + 2)",  ["left >= ?", right_bound] )
          self.class.base_class.update_all( "right = (right + 2)",  ["right >= ?", right_bound] )
        else
          last_root = self.class.find(:first, :order => 'right DESC', :conditions => { :parent_id => nil })
          self.left = last_root ? (last_root.right + 1) : 1
          self.right = last_root ? (last_root.right + 2) : 2
        end
      end
    end
    
    def fetch_descendants
      descendants = self.class.base_class.find_descendants(self)
      children = self.class.base_class.sort_nodes_to_nested_set(descendants)
      return [descendants, children]
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
      include NestedSetMethods
      extend NestedSetClassMethods
      named_scope :roots, :conditions => { :parent_id => nil}
      
      before_create :append_node
      after_destroy :remove_node
      #attr_protected :left, :right
    end
    
  end
  
end

ActiveRecord::Base.send(:include, EvenBetterNestedSet)