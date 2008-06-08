path = File.join(File.dirname(__FILE__), 'even_better_nested_set/')

require path + 'child_association_proxy'

module EvenBetterNestedSet
  
  def self.included(base)
    super
    base.extend ClassMethods
  end
  
  module NestedSetMethods
    
    def patriarch
      transaction do
        self.left, self.right = base_class.find_boundaries(self.id)
        @patriarch ||= base_class.roots.find(:first, :conditions => ["`left` < ? AND `right` > ?", left, right])
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
    
    def illegal_nesting
      if parent and descendants.include?(parent)
        errors.add(:parent_id, 'cannot move node to its own descendant')
      end
    end
    
    def remove_node
      base_class.delete_all ['`left` > ? AND `right` < ?', left, right] # TODO: Figure out what to do with children's destroy callbacks
      
      shift!(-node_width, right)
    end
    
    def append_node
      boundary = 1
      
      if parent_id?
        transaction do
          boundary = parent(true).right
          shift! 2, boundary
        end      
      elsif last_root = base_class.find_last_root
        boundary = last_root.right + 1
      end
      
      self.left  = boundary
      self.right = left + 1
    end
    
    def move_node
      if parent_id_changed?
        transaction do
          self.left, self.right = base_class.find_boundaries(self.id)
          
          if parent_id.blank? # moved to root
            shift_difference = base_class.find_last_root.right - left + 1
          else # moved to non-root
            new_parent = base_class.find_by_id(parent_id)

            # open up a space
            boundary = new_parent.right
            shift! node_width, boundary
            
            self.left, self.right = base_class.find_boundaries(self.id)
            
            shift_difference = (new_parent.right - left)
          end
          # move itself and children into place
          shift! shift_difference, left, right
          
          # close up the space that was left behind after move
          shift! -node_width, left
          
          self.left, self.right = base_class.find_boundaries(self.id)
        end
      end
    end
    
    def shift!(positions, left_boundary, right_boundary=nil)
      if right_boundary
        base_class.update_all "`left`  = (`left`  + #{positions})", ["`left`  >= ? AND `left`  <= ?", left_boundary, right_boundary]
        base_class.update_all "`right` = (`right` + #{positions})", ["`right` >= ? AND `right` <= ?", left_boundary, right_boundary]
      else
        base_class.update_all "`left`  = (`left`  + #{positions})", ["`left` >= ?", left_boundary]
        base_class.update_all "`right` = (`right` + #{positions})", ["`right` >= ?", left_boundary]
      end
    end
    
    def fetch_descendants
      transaction do
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
    
    def find_boundaries(id)
      connection.select_rows("SELECT left, right FROM `#{table_name}` WHERE `#{primary_key}` = #{id}").first
    end
    
    def find_descendants(node)
      transaction do
        left, right = base_class.find_boundaries(node.id)
        find(:all, :order => '`left` ASC', :conditions => ["`left` > ? AND `right` < ?", left, right])
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

      named_scope :roots, :conditions => { :parent_id => nil}
      has_many :children, :class_name => self.name, :foreign_key => :parent_id
      belongs_to :parent, :class_name => self.name, :foreign_key => :parent_id

      include NestedSetMethods
      extend NestedSetClassMethods
      
      before_create :append_node
      before_update :move_node
      before_destroy :reload
      after_destroy :remove_node
      validate_on_update :illegal_nesting
      
      #attr_protected :left, :right
    end
    
  end
  
end

ActiveRecord::Base.send(:include, EvenBetterNestedSet)