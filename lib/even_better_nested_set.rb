path = File.join(File.dirname(__FILE__), 'even_better_nested_set/')

require path + 'child_association_proxy'

module EvenBetterNestedSet
  
  def self.included(base)
    super
    base.extend ClassMethods
  end
  
  module NestedSetMethods
    
    def parent=(new_parent)
      return if new_parent == parent
      @moved = true
      @parent = new_parent
      self.parent_id = new_parent ? parent.id : nil
    end
    
    def parent(reload=false)
      @parent = nil if reload
      @parent ||= base_class.find_by_id(parent_id)
    end
    
    def children
      return @children if @children
      @descendants, @children = fetch_descendants
      @children
    end
    
    def patriarch
      transaction do
        reload
        @patriarch ||= base_class.find(:first, :conditions => ["`left` < ? AND `right` > ? AND parent_id IS NULL", left, right])
      end
    end
    
    def descendants
      return @descendants if @descendants
      @descendants, @children = fetch_descendants
      @descendants
    end
    
    def nested_set
      children
    end
    
    def generation
      @generation ||= parent ? parent.nested_set : base_class.nested_set
    end
    
    def siblings
      @siblings ||= (generation - [self])
    end
    
    def bounds
      left..right
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
      base_class.delete_all ['`left` > ? AND `right` < ?', left, right] # TODO: Figure out what to do with children's destroy callbacks
      
      shift_left! node_width, right
    end
    
    def append_node
      boundary = 1
      
      if parent
        transaction do
          boundary = parent(true).right
          shift_right! 2, boundary
        end      
      elsif last_root = base_class.find_last_root
        boundary = last_root.right + 1
      end
      
      self.left  = boundary
      self.right = left + 1
    end
    
    def move_node
      if @moved
        transaction do
          reload
          
          if @parent # moved to non-root
            @parent.reload

            # open up a space
            boundary = @parent.right
            shift_right! node_width, boundary
            reload
          
            shift_difference = @parent.right - self.left
          else # moved to root
            shift_difference = base_class.find_last_root.right - left + 1
          end
          
          # move itself and children into place
          shift_right! shift_difference, left, right # shifts left if shift_diff is negative
          
          # close up the space that was left behind after move
          shift_left! node_width, left
        end
      end
    end
    
    def shift_left!(positions, left_boundary, right_boundary=nil)
      shift! '-', positions, left_boundary, right_boundary
    end
    
    def shift_right!(positions, left_boundary, right_boundary=nil)
      shift! '+', positions, left_boundary, right_boundary
    end
    
    def shift!(direction, positions, left_boundary, right_boundary=nil)
      if right_boundary
        base_class.update_all "`left`  = (`left`  #{direction} #{positions})", ["`left`  >= ? AND `left`  <= ?", left_boundary, right_boundary]
        base_class.update_all "`right` = (`right` #{direction} #{positions})", ["`right` >= ? AND `right` <= ?", left_boundary, right_boundary]
      else
        base_class.update_all "`left`  = (`left`  #{direction} #{positions})", ["`left` >= ?", left_boundary]
        base_class.update_all "`right` = (`right` #{direction} #{positions})", ["`right` >= ?", left_boundary]
      end
    end
    
    def fetch_descendants
      transaction do
        reload
        ds = base_class.find_descendants(self)
        [ds, base_class.sort_nodes_to_nested_set(ds)]
      end
    end
    
    def node_width
      right - left + 1
    end
    
    def base_class
      self.class.base_class
    end
  end
  
  module NestedSetClassMethods
    
    def find_last_root
      find(:first, :order => '`right` DESC', :conditions => { :parent_id => nil })
    end
    
    def find_descendants(node)
      transaction do
        node.reload
        find(:all, :order => '`left` ASC', :conditions => ["`left` > ? AND `right` < ?", node.left, node.right])
      end
    end
    
    def nested_set(parent=nil)
      if parent
        sort_nodes_to_nested_set(find_descendants(parent))
      else
        sort_nodes_to_nested_set(find(:all, :order => '`left` ASC'))
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