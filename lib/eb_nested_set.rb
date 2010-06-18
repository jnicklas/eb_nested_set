module EvenBetterNestedSet
  
  class NestedSetError < StandardError; end
  class IllegalAssignmentError < NestedSetError; end

  ##
  # Declare this model as a nested set. Automatically adds all methods in
  # +EvenBetterNestedSet::NestedSet+ to the model, as well as parent and
  # children associations.
  #
  # == Options
  # left [Symbol]:: the name of the column that contains the left boundary [Defaults to +left+]
  # right [Symbol]:: the name of the column that contains the right boundary [Defaults to +right+]
  # scope [Symbol]:: the name of an association to scope this nested set to
  #
  # @param [Hash] options a set of options
  #
  def acts_as_nested_set(options={})
    options = { :left => :left, :right => :right }.merge!(options)
    options[:scope] = "#{options[:scope]}_id" if options[:scope]

    include NestedSet

    self.nested_set_options = options

    class_eval <<-RUBY, __FILE__, __LINE__+1
      def #{options[:left]}=(left)
        raise EvenBetterNestedSet::IllegalAssignmentError, "#{options[:left]} is an internal attribute used by EvenBetterNestedSet, do not assign it directly as is may corrupt the data in your database"
      end

      def #{options[:right]}=(right)
        raise EvenBetterNestedSet::IllegalAssignmentError, "#{options[:right]} is an internal attribute used by EvenBetterNestedSet, do not assign it directly as is may corrupt the data in your database"
      end
    RUBY

    named_scope :roots, :conditions => { :parent_id => nil }
    has_many :children, :class_name => self.name, :foreign_key => :parent_id
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

  module NestedSet
    
    def self.included(base)
      super
      base.extend ClassMethods
    end
    
    module ClassMethods
      
      attr_accessor :nested_set_options
      
      ##
      # Finds the last root, used internally to find the point to insert new roots
      #
      # @return [ActiveRecord::Base] the last root node
      #
      def find_last_root
        find(:first, :order => "#{nested_set_column(:right)} DESC", :conditions => { :parent_id => nil })
      end

      ##
      # Finds the left and right boundaries of a node given an id.
      #
      # @return [Array[Integer]] left and right boundaries
      #
      def find_boundaries(id)
        query = "SELECT #{nested_set_column(:left)}, #{nested_set_column(:right)}" +
                "FROM #{quote_db_property(table_name)}" +
                "WHERE #{quote_db_property(primary_key)} = #{id}"
        connection.select_rows(query).first
      end

      ##
      # Returns all nodes with children cached to a nested set
      #
      # @return [Array[ActiveRecord::Base]] an array of root nodes with cached children
      #
      def nested_set
        sort_nodes_to_nested_set(find(:all, :order => "#{nested_set_column(:left)} ASC"))
      end
      
      ##
      # Finds all nodes matching the criteria provided, and caches their descendants
      #
      # @param [Object] *args same parameters as ordinary find calls
      # @return [Array[ActiveRecord::Base], ActiveRecord::Base] the found nodes
      #
      def find_with_nested_set(*args)
        result = find(*args)
        if result.respond_to?(:cache_nested_set)
          result.cache_nested_set
        elsif result.respond_to?(:each)
          result.each do |node|
            node.cache_nested_set
          end
        end
        result
      end

      ##
      # Given a flat list of nodes, sorts them to a tree, caching descendants in the process
      #
      # @param [Array[ActiveRecord::Base]] nodes an array of nodes
      # @return [Array[ActiveRecord::Base]] an array of nodes with children cached
      #
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
      
      ##
      # Returns the properly quoted column name given the generic term
      #
      # @param [Symbol] name the name of the column to find
      # @return [String]
      def nested_set_column(name)
        quote_db_property(nested_set_options[name])
      end
      
      ##
      # Recalculates the left and right values for the entire tree
      #
      def recalculate_nested_set
        transaction do
          left = 1
          roots.each do |root|
            left = root.recalculate_nested_set(left)
          end
        end
      end
      
      ##
      # Properly quotes a column name
      #
      # @param [String] property
      # @return [String] quoted property
      #
      def quote_db_property(property)
        connection.quote_column_name(property)
      end
      
    end
    
    ##
    # Checks if this root is a root node
    #
    # @return [Boolean] whether this node is a root node or not
    #
    def root?
      not parent_id?
    end
    
    ##
    # Checks if this node is a descendant of node
    #
    # @param [ActiveRecord::Base] node the node to check agains
    # @return [Boolean] whether this node is a descendant
    #
    def descendant_of?(node)
      node.left < self.left && self.right < node.right
    end
  
    ##
    # Finds the root node that this node descends from
    #
    # @param [Boolean] force_reload forces the root node to be reloaded
    # @return [ActiveRecord::Base] node the root node this descends from
    #
    def root(force_reload=nil)
      @root = nil if force_reload
      @root ||= transaction do
        reload_boundaries
        base_class.roots.find(:first, :conditions => ["#{nested_set_column(:left)} <= ? AND #{nested_set_column(:right)} >= ?", left, right])
      end
    end
    
    alias_method :patriarch, :root
    
    ##
    # Returns a list of ancestors this node belongs to
    #
    # @param [Boolean] force_reload forces the list to be reloaded
    # @return [Array[ActiveRecord::Base]] a list of nodes that this node descends from
    #
    def ancestors(force_reload=false)
      @ancestors = nil if force_reload
      @ancestors ||= base_class.find(
        :all,:conditions => ["#{nested_set_column(:left)} < ? AND #{nested_set_column(:right)} > ?", left, right],
        :order => "#{nested_set_column(:left)} DESC"
      )
    end
    
    ##
    # Returns a list of the node itself and all of its ancestors
    #
    # @param [Boolean] force_reload forces the list to be reloaded
    # @return [Array[ActiveRecord::Base]] a list of nodes that this node descends from
    #
    def lineage(force_reload=false)
      [self, *ancestors(force_reload)]
    end
    
    ##
    # Returns all nodes that descend from the same root node as this node
    #
    # @return [Array[ActiveRecord::Base]]
    #
    def kin
      patriarch.family
    end
    
    ##
    # Returns all nodes that descend from this node
    #
    # @return [Array[ActiveRecord::Base]]
    #
    def descendants
      base_class.descendants(self)
    end
    
    ##
    # Caches the children of this node
    #
    def cache_nested_set
      @cached_children || base_class.sort_nodes_to_nested_set(family)
    end
    
    ##
    # Returns the node and all nodes that descend from it.
    #
    # @return [Array[ActiveRecord::Base]]
    #
    def family
      [self, *descendants]
    end
    
    ##
    # Returns the ids of the node and all nodes that descend from it.
    #
    # @return [Array[Integer]]
    #
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
    
    ##
    # Returns all nodes that share the same parent as this node.
    #
    # @return [Array[ActiveRecord::Base]]
    #
    def generation
      root? ? base_class.roots : parent.children
    end
    
    ##
    # Returns all nodes that are siblings of this node
    #
    # @return [Array[ActiveRecord::Base]]
    #
    def siblings
      generation - [self]
    end
    
    ##
    # Returns how deeply this node is nested, that is how many ancestors it has.
    #
    # @return [Integer] the number of ancestors of this node.
    #
    def level
      if root?
        0
      elsif @ancestors
        @ancestors.size
      else
        base_class.count :conditions => ["#{nested_set_column(:left)} < ? AND #{nested_set_column(:right)} > ?", left, right]
      end
    end
    
    ##
    # @return [Range] the left to the right boundary of this node
    #
    def bounds
      left..right
    end
    
    ##
    # @return [Integer] the left boundary of this node
    #
    def left
      read_attribute(self.class.nested_set_options[:left])
    end
    
    ##
    # @return [Integer] the right boundary of this node
    #
    def right
      read_attribute(self.class.nested_set_options[:right])
    end
    
    ##
    # Caches the node as this node's parent.
    #
    def cache_parent(parent) #:nodoc:
      self.parent = parent
    end
    
    ##
    # Caches the nodes as this node's children.
    #
    def cache_children(*nodes) #:nodoc:
      @cached_children ||= []
      children.target = @cached_children.push(*nodes)
    end

    ##
    # Rebuild this node's childrens boundaries
    #
    def recalculate_nested_set(left) #:nodoc:
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
        errors.add(:parent_id, I18n.t('eb_nested_set.illegal_nesting', :default => 'cannot move node to its own descendant'))
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
          message = I18n.t('eb_nested_set.parent_not_in_scope',
            :default => "cannot be a record with a different {{scope_name}} to this record",
            :scope_name => self.class.nested_set_options[:scope]
          )
          errors.add(:parent_id, message)
        end
      end
    end
  end
  
end

ActiveRecord::Base.extend EvenBetterNestedSet if defined?(ActiveRecord)
