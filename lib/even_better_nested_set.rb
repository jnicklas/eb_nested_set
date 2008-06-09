module EvenBetterNestedSet
  
  def self.included(base)
    super
    base.extend ClassMethods
  end
  
  class NestedSetError < StandardError; end
  class IllegalAssignmentError < NestedSetError; end
  
  module NestedSet
    
    def self.included(base)
      super
      base.extend ClassMethods
    end
    
    module ClassMethods

      def find_last_root
        find(:first, :order => '`right` DESC', :conditions => { :parent_id => nil })
      end

      def find_boundaries(id)
        connection.select_rows("SELECT `left`, `right` FROM `#{table_name}` WHERE `#{primary_key}` = #{id}").first
      end

      def find_descendants(node)
        transaction do
          left, right = base_class.find_boundaries(node.id)
          find(:all, :order => '`left` ASC', :conditions => ["`left` > ? AND `right` < ?", left, right])
        end
      end

      def nested_set
        sort_nodes_to_nested_set(find(:all, :order => '`left` ASC'))
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
            parent.cache_children(node)
          else
            roots << node
          end

          hashmap[node.id] = node
        end
        return roots
      end

    end
    
    def root?
      not parent_id?
    end
    
    def root
      transaction do
        reload_boundaries
        @root ||= base_class.roots.find(:first, :conditions => ["`left` <= ? AND `right` >= ?", left, right])
      end
    end
    
    alias_method :patriarch, :root
    
    def ancestors(force_reload=false)
      @ancestors = nil if force_reload
      @ancestors ||= base_class.find :all, :conditions => ["left < ? AND right > ?", left, right], :order => 'left DESC'
    end
    
    def kin
      patriarch.family
    end
    
    def descendants
      base_class.find_descendants(self)
    end
    
    def cache_nested_set
      @cached_children || base_class.sort_nodes_to_nested_set(family)
    end
    
    def family
      descendants.unshift(self)
    end
    
    def family_ids(force_reload=false)
      return @family_ids unless @family_ids.nil? or force_reload
      
      transaction do
        reload_boundaries
        query = "SELECT id FROM `#{base_class.table_name}` WHERE `left` >= #{left} AND `right` <= #{right} ORDER BY `left`"
        @family_ids = base_class.connection.select_values(query).map(&:to_i)
      end
    end
    
    def generation
      root? ? base_class.roots : parent.children
    end
    
    def siblings
      generation - [self]
    end
    
    def level
      if root?
        0
      elsif @ancestors
        @ancestors.size
      else
        base_class.count :conditions => ["left < ? AND right > ?", left, right]
      end
    end
    
    def bounds
      left..right
    end
    
    def cache_parent(parent) #:nodoc:
      self.parent = parent
    end
    
    def cache_children(*nodes) #:nodoc:
      @cached_children ||= []
      children.target = @cached_children.push(*nodes)
    end

    def left=(left) #:nodoc:
      raise EvenBetterNestedSet::IllegalAssignmentError, "left is an internal attribute used by EvenBetterNestedSet, do not assign it directly as is may corrupt the data in your database"
    end
    
    def right=(right) #:nodoc:
      raise EvenBetterNestedSet::IllegalAssignmentError, "right is an internal attribute used by EvenBetterNestedSet, do not assign it directly as is may corrupt the data in your database"
    end
    
    protected
    
    def illegal_nesting
      if parent_id? and family_ids.include?(parent_id)
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
      
      set_boundaries(boundary, boundary + 1)
    end
    
    def move_node
      if parent_id_changed?
        transaction do
          reload_boundaries
          
          if parent_id.blank? # moved to root
            shift_difference = base_class.find_last_root.right - left + 1
          else # moved to non-root
            new_parent = base_class.find_by_id(parent_id)

            # open up a space
            boundary = new_parent.right
            shift! node_width, boundary
            
            reload_boundaries
            
            shift_difference = (new_parent.right - left)
          end
          # move itself and children into place
          shift! shift_difference, left, right
          
          # close up the space that was left behind after move
          shift! -node_width, left
          
          reload_boundaries
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
    
    def node_width
      right - left + 1
    end
    
    def set_boundaries(left, right)
      write_attribute(:left, left)
      write_attribute(:right, right)
    end
        
    def reload_boundaries
      set_boundaries(*base_class.find_boundaries(id))
    end
    
    def base_class
      self.class.base_class
    end
  end
  
  module ClassMethods
    
    def acts_as_nested_set

      named_scope :roots, :conditions => { :parent_id => nil}
      has_many :children, :class_name => self.name, :foreign_key => :parent_id
      belongs_to :parent, :class_name => self.name, :foreign_key => :parent_id

      include NestedSet
      
      before_create :append_node
      before_update :move_node
      before_destroy :reload
      after_destroy :remove_node
      validate_on_update :illegal_nesting
    end
    
  end
  
end

ActiveRecord::Base.send(:include, EvenBetterNestedSet)