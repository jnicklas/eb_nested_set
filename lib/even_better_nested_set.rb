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
      
      attr_accessor :nested_set_options
      
      def find_last_root
        find(:first, :order => "#{nested_set_column(:right)} DESC", :conditions => { :parent_id => nil })
      end

      def find_boundaries(id)
        query = "SELECT #{nested_set_column(:left)}, #{nested_set_column(:right)}" +
                "FROM #{quote_db_property(table_name)}" +
                "WHERE #{quote_db_property(primary_key)} = #{id}"
        connection.select_rows(query).first
      end

      def nested_set
        sort_nodes_to_nested_set(find(:all, :order => "#{nested_set_column(:left)} ASC"))
      end

      def sort_nodes_to_nested_set(nodes)
        roots = []
        hashmap = {}
        for node in nodes.sort_by { |n| n.left }
          # if the parent is not in the hashmap, parent will be nil, therefore node will be a root node
          # in that case
          parent = node.parent_id ? hashmap[node.parent_id] : nil
          
          # make sure this is called at least once on every node, so leaves know that they have *no* children
          node.cache_children()

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
      
      def nested_set_column(name)
        quote_db_property(nested_set_options[name])
      end
      
      # Recalculates the left and right values for the entire tree
      def recalculate_nested_set
        transaction do
          left = 1
          roots.each do |root|
            left = root.recalculate_nested_set(left)
          end
        end
      end
      
      def quote_db_property(property)
        "`#{property}`".gsub('.','`.`')
      end
      
    end
    
    def root?
      not parent_id?
    end
    
    def descendant_of?(node)
      node.left < self.left && self.right < node.right
    end
  
    def root
      transaction do
        reload_boundaries
        @root ||= base_class.roots.find(:first, :conditions => ["#{nested_set_column(:left)} <= ? AND #{nested_set_column(:right)} >= ?", left, right])
      end
    end
    
    alias_method :patriarch, :root
    
    def ancestors(force_reload=false)
      @ancestors = nil if force_reload
      @ancestors ||= base_class.find(
        :all,:conditions => ["#{nested_set_column(:left)} < ? AND #{nested_set_column(:right)} > ?", left, right],
        :order => "#{nested_set_column(:left)} DESC"
      )
    end
    
    def lineage(force_reload=false)
      [self, *ancestors(force_reload)]
    end
    
    def kin
      patriarch.family
    end
    
    def descendants
      base_class.descendants(self)
    end
    
    def cache_nested_set
      @cached_children || base_class.sort_nodes_to_nested_set(family)
    end
    
    def family
      [self, *descendants]
    end
    
    def family_ids(force_reload=false)
      return @family_ids unless @family_ids.nil? or force_reload
      
      transaction do
        reload_boundaries
        query = "SELECT id FROM #{self.class.quote_db_property(base_class.table_name)} " + 
                "WHERE #{nested_set_column(:left)} >= #{left} AND #{nested_set_column(:right)} <= #{right} " +
                "ORDER BY #{nested_set_column(:left)}"
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
        base_class.count :conditions => ["#{nested_set_column(:left)} < ? AND #{nested_set_column(:right)} > ?", left, right]
      end
    end
    
    def bounds
      left..right
    end
    
    def children
      @cached_children || uncached_children
    end
    
    def cache_parent(parent) #:nodoc:
      self.parent = parent
    end
    
    def cache_children(*nodes) #:nodoc:
      @cached_children ||= []
      @cached_children.push(*nodes)
    end
    
    def left
      read_attribute(self.class.nested_set_options[:left])
    end
    
    def left=(left) #:nodoc:
      raise EvenBetterNestedSet::IllegalAssignmentError, "left is an internal attribute used by EvenBetterNestedSet, do not assign it directly as is may corrupt the data in your database"
    end
    
    def right
      read_attribute(self.class.nested_set_options[:right])
    end
    
    def right=(right) #:nodoc:
      raise EvenBetterNestedSet::IllegalAssignmentError, "right is an internal attribute used by EvenBetterNestedSet, do not assign it directly as is may corrupt the data in your database"
    end
    
    def recalculate_nested_set(left)
      child_left = left + 1
      children.each do |child|
        child_left = child.recalculate_nested_set(child_left)
      end
      set_boundaries(left, child_left)
      save_without_validation!
      
      right + 1
    end
    
    protected
    
    def illegal_nesting
      if parent_id? and family_ids.include?(parent_id)
        errors.add(:parent_id, 'cannot move node to its own descendant')
      end
    end
    
    def remove_node
      base_class.delete_all ["#{nested_set_column(:left)} > ? AND #{nested_set_column(:right)} < ?", left, right] # TODO: Figure out what to do with children's destroy callbacks
      
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
        base_class.update_all "#{nested_set_column(:left)}  = (#{nested_set_column(:left)}  + #{positions})", ["#{nested_set_column(:left)}  >= ? AND #{nested_set_column(:left)}  <= ?", left_boundary, right_boundary]
        base_class.update_all "#{nested_set_column(:right)} = (#{nested_set_column(:right)} + #{positions})", ["#{nested_set_column(:right)} >= ? AND #{nested_set_column(:right)} <= ?", left_boundary, right_boundary]
      else
        base_class.update_all "#{nested_set_column(:left)}  = (#{nested_set_column(:left)}  + #{positions})", ["#{nested_set_column(:left)} >= ?", left_boundary]
        base_class.update_all "#{nested_set_column(:right)} = (#{nested_set_column(:right)} + #{positions})", ["#{nested_set_column(:right)} >= ?", left_boundary]
      end
    end
    
    def node_width
      right - left + 1
    end
    
    def set_boundaries(left, right)
      write_attribute(self.class.nested_set_options[:left], left)
      write_attribute(self.class.nested_set_options[:right], right)
    end
        
    def reload_boundaries
      set_boundaries(*base_class.find_boundaries(id))
    end
    
    def base_class
      self.class.base_class
    end
    
    def validate_parent_is_within_scope
      if self.class.nested_set_options[:scope] && parent_id
        parent.reload # Make sure we are testing the record corresponding to the parent_id
        if self.send(self.class.nested_set_options[:scope]) != parent.send(self.class.nested_set_options[:scope])
          errors.add(:parent_id, "cannot be a record with a different #{self.class.nested_set_options[:scope]} to this record")
        end
      end
    end
  end
  
  module ClassMethods
    
    def acts_as_nested_set(options = {})
      options = { :left => :left, :right => :right }.merge!(options)
      options[:scope] = "#{options[:scope]}_id" if options[:scope]
      
      include NestedSet
      
      self.nested_set_options = options
      
      named_scope :roots, :conditions => { :parent_id => nil }, :order => "#{nested_set_column(:left)} asc"
      
      has_many :uncached_children, :class_name => self.name, :foreign_key => :parent_id, :order => "#{nested_set_column(:left)} asc"
      protected :uncached_children, :uncached_children=
      
      belongs_to :parent, :class_name => self.name, :foreign_key => :parent_id
      
      named_scope :descendants, lambda { |node|
        left, right = find_boundaries(node.id)
        { :conditions => ["#{nested_set_column(:left)} > ? and #{nested_set_column(:right)} < ?", left, right],
          :order => "#{nested_set_column(:left)} asc" }
      }
      
      before_create :append_node
      before_update :move_node
      before_destroy :reload
      after_destroy :remove_node
      validate_on_update :illegal_nesting
      validate :validate_parent_is_within_scope
      
      delegate :nested_set_column, :to => "self.class"
    end
    
  end
  
end

ActiveRecord::Base.send(:include, EvenBetterNestedSet) if defined?(ActiveRecord)
