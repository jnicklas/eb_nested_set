path = File.join(File.dirname(__FILE__), 'even_better_nested_set/')

require path + 'child_association_proxy'

module EvenBetterNestedSet
  
  def self.included(base)
    super
    base.extend ClassMethods
  end
  
  module NestedSetMethods
    
    def parent=(new_parent)
      return if new_parent == self.parent
      @moved = true
      @parent = new_parent
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
      transaction do
        self.reload
        @patriarch ||= self.class.base_class.find(:first, :conditions => ["`left` < ? AND `right` > ? AND parent_id IS NULL", self.left, self.right])
      end
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
      self.class.base_class.delete_all(['`left` > ? AND `right` < ?', self.left, self.right])
      
      self.shift_left!(difference, self.right)
    end
    
    def append_node
      transaction do
        if self.parent
          self.parent.reload
          boundary = self.parent.right
          self.left = boundary
          self.right = boundary + 1
        
          self.shift_right!(2, boundary)
        else
          last_root = self.class.base_class.find(:first, :order => '`right` DESC', :conditions => { :parent_id => nil })
          self.left = last_root ? (last_root.right + 1) : 1
          self.right = last_root ? (last_root.right + 2) : 2
        end
      end
    end
    
    def move_node
      transaction do
        if @moved
          self.reload
          difference = self.right - self.left + 1
          
          # moved to non-root
          if @parent
            @parent.reload
            
            # open up a space
            self.shift_right!(difference, @parent.right)
            self.reload
          
            # move itself and children into the opened space 
            shift_difference = @parent.right - self.left
            self.shift_right!(shift_difference, self.left, self.right) # shifts left if shift_diff is negative
          
            # close up the space that was left behind after move
            self.shift_left!(difference, self.left)
          # moved to root
          else
            last_root = self.class.base_class.find(:first, :order => '`right` DESC', :conditions => { :parent_id => nil })
            
            # move to end of tree, after last root node
            shift_difference = last_root.right - self.left + 1
            self.shift_right!(shift_difference, self.left, self.right)
          
            # close up the space that was left behind after move
            self.shift_left!(difference, self.left)          
          end
        end
      end
    end
    
    def shift_left!(positions, left_boundary, right_boundary=nil)
      shift!('-', positions, left_boundary, right_boundary)
    end
    
    def shift_right!(positions, left_boundary, right_boundary=nil)
      shift!('+', positions, left_boundary, right_boundary)
    end
    
    def shift!(direction, positions, left_boundary, right_boundary=nil)
      if right_boundary
        self.class.base_class.update_all( "`left` = (`left` #{direction} #{positions})",  ["`left` >= ? AND `left` <= ?", left_boundary, right_boundary] )
        self.class.base_class.update_all( "`right` = (`right` #{direction} #{positions})",  ["`right` >= ? AND `right` <= ?", left_boundary, right_boundary] )
      else
        self.class.base_class.update_all( "`left` = (`left` #{direction} #{positions})",  ["`left` >= ?", left_boundary] )
        self.class.base_class.update_all( "`right` = (`right` #{direction} #{positions})",  ["`right` >= ?", left_boundary] )        
      end
    end
    
    def fetch_descendants
      ds = nil
      transaction do
        self.reload
        ds = self.class.base_class.find_descendants(self)
      end
      children = self.class.base_class.sort_nodes_to_nested_set(ds)
      return [ds, children]
    end
  end
  
  module NestedSetClassMethods
    
    def find_descendants(node)
      transaction do
        node.reload
        self.find(:all, :order => '`left` ASC', :conditions => ["`left` > ? AND `right` < ?", node.left, node.right])
      end
    end
    
    def nested_set(parent=nil)
      if parent
        sort_nodes_to_nested_set(self.find_descendants(parent))
      else
        sort_nodes_to_nested_set(self.find(:all, :order => '`left` ASC'))
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
      before_update :move_node
      before_destroy :reload # make sure we are working with the latest version of the node
      after_destroy :remove_node
      #attr_protected :left, :right
    end
    
  end
  
end

ActiveRecord::Base.send(:include, EvenBetterNestedSet)