describe "all nested set models", :shared => true do

  describe @model, 'model with acts_as_nested_set' do
  
    before do
      @instance = @model.new(valid_attributes)
    end
    
    #FIXME: wtf??? throws weird errors
    it "should protect left and right from mass assignment" do
      #@instance.attributes = { :left => 3, :right => 6 }
      #@instance.left.should be_nil
      #@instance.right.should be_nil
    end
  
    describe '#bounds' do
    
      it "should return a range, from left to right" do
        @instance.left = 3
        @instance.right = 6
        @instance.bounds.should == (3..6)
      end
    
    end

  end
  
  describe @model, "with many descendants" do
    before do
      @r1 = @model.create!(valid_attributes)
      @r2 = @model.create!(valid_attributes)
      @r3 = @model.create!(valid_attributes)

      @r1c1 = @model.create!(valid_attributes(:parent => @r1))
      @r1c2 = @model.create!(valid_attributes(:parent => @r1))
      @r1c3 = @model.create!(valid_attributes(:parent => @r1))
      @r2c1 = @model.create!(valid_attributes(:parent => @r2))

      @r1c1s1 = @model.create!(valid_attributes(:parent => @r1c1))
      @r1c2s1 = @model.create!(valid_attributes(:parent => @r1c2))
      @r1c2s2 = @model.create!(valid_attributes(:parent => @r1c2))
      @r1c2s3 = @model.create!(valid_attributes(:parent => @r1c2))

      @r1c2s2m1 = @model.create!(valid_attributes(:parent => @r1c2s2))
    end
    
    after do
      @model.delete_all
    end
    
    it "should find all root nodes" do
      @model.roots.all.should == [@r1, @r2, @r3]
    end
    
    it "should find a root nodes" do
      @model.roots.first.should == @r1
    end
    
    it "should maintain the integrity of the tree if a node is deleted" do
      @r1c2.destroy
      
      @r1.reload
      @r1c3.reload
      
      @r1.left.should == 1
      @r1.right.should == 8
      @r1c3.left.should == 6
      @r1c3.right.should == 7
    end
    
    it "should maintain the integrity of the tree if a node is moved" do
      @r1c2.parent = @r2
      @r1c2.save!
      
      @r1.reload
      @r1c3.reload
      @r2.reload
      @r1c2.reload
      @r1c2s1.reload
      
      @r1.left.should == 1
      @r1.right.should == 8
      @r1c3.left.should == 6
      @r1c3.right.should == 7
      
      @r2.left.should == 9
      @r2.right.should == 22
      
      @r1c2.left.should == 12
      @r1c2.right.should == 21
      
      @r1c2s1.left.should == 13
      @r1c2s1.right.should == 14
    end
    
    it "should maintain the integrity of the tree if a node is moved to a root position" do
      @r1c2.parent = nil
      @r1c2.save!
      
      @r1.reload
      @r1c3.reload
      @r2.reload
      @r1c2.reload
      @r1c2s1.reload
      
      @r1.left.should == 1
      @r1.right.should == 8
      @r1c3.left.should == 6
      @r1c3.right.should == 7
      
      @r1c2.left.should == 15
      @r1c2.right.should == 24
      
      @r1c2s1.left.should == 16
      @r1c2s1.right.should == 17
    end
    
    it "should maintain the integrity of the tree if a root is to a non-root position" do
      @r1c2.reload
      @r2.parent = @r1c2
      @r2.save!
      
      @r1.reload
      @r2.reload
      @r2c1.reload
      @r1c3.reload
      @r3.reload
      @r1c2.reload
      
      @r1c2.right.should == 19      
      @r1.right.should == 22

      @r1c3.left.should == 20
      @r1c3.right.should == 21
      
      @r3.left.should == 23
      @r3.right.should == 24
      
      @r2.left.should == 15
      @r2.right.should == 18
      
      @r2c1.left.should == 16
      @r2c1.right.should == 17
    end
    
    it "should be invalid if parent is a descendant" do
      @r2.parent = @r2c1
      @r2.should_not be_valid
    end
    
    describe ".nested_set" do
      it "should find all nodes as a nested set" do
        roots = @model.nested_set
        
        roots[0].should == @r1
        roots[0].children[0].should == @r1c1
        roots[0].children[0].children[0].should == @r1c1s1
        roots[0].children[1].should == @r1c2
        roots[0].children[1].children[0].should == @r1c2s1
        roots[0].children[1].children[1].should == @r1c2s2
        roots[0].children[1].children[1].children[0].should == @r1c2s2m1
        roots[0].children[1].children[2].should == @r1c2s3
        roots[0].children[2].should == @r1c3
        roots[1].should == @r2
        roots[1].children[0].should == @r2c1
        roots[2].should == @r3
      end
      
      it "should find nodes for a specific parent as a nested set" do
        roots = @model.nested_set(@r1c2)
        
        roots[0].should == @r1c2s1
        roots[1].should == @r1c2s2
        roots[1].children[0].should == @r1c2s2m1
        roots[2].should == @r1c2s3
      end
    end
    
    describe ".sort_nodes_to_nested_set" do
      
      it "should accept a list of nodes and sort them to a nested set" do
        roots = @model.sort_nodes_to_nested_set(@model.find(:all))
        roots[0].should == @r1
        roots[0].children[0].should == @r1c1
        roots[0].children[0].children[0].should == @r1c1s1
        roots[0].children[1].should == @r1c2
        roots[0].children[1].children[0].should == @r1c2s1
        roots[0].children[1].children[1].should == @r1c2s2
        roots[0].children[1].children[1].children[0].should == @r1c2s2m1
        roots[0].children[1].children[2].should == @r1c2s3
        roots[0].children[2].should == @r1c3
        roots[1].should == @r2
        roots[1].children[0].should == @r2c1
        roots[2].should == @r3
      end
      
    end
    
    describe ".find_descendants" do
      
      it "should find all descendants for a specific node" do
        
        roots = @model.find_descendants(@r1c2)
        
        roots[0].should == @r1c2s1
        roots[1].should == @r1c2s2
        roots[2].should == @r1c2s2m1
        roots[3].should == @r1c2s3
        
      end
      
    end
    
    describe "#nested_set" do
      
      it "should find descendant nodes for this node as a nested set" do
        roots = @r1c2.nested_set
        
        roots[0].should == @r1c2s1
        roots[1].should == @r1c2s2
        roots[1].children[0].should == @r1c2s2m1
        roots[2].should == @r1c2s3
      end
      
    end
    
    describe "#parent" do
      
      it "should find the parent node" do
        @r1c1.parent.should == @r1
        @r1c2s2.parent.should == @r1c2
        @r1c2s2m1.parent.should == @r1c2s2
      end
      
    end
    
    describe "#children" do
      
      it "should find all nodes that are direct descendants of this one" do
        @r1.children.should == [@r1c1, @r1c2, @r1c3]
        @r1c2s2.children.should == [@r1c2s2m1]
      end
      
    end
    
    describe "#patriarch" do
      
      it "should find the root node that this node descended from" do
        @r1c1.patriarch.should == @r1
        @r1c2s2.patriarch.should == @r1
        @r1c2s2m1.patriarch.should == @r1
        @r2c1.patriarch.should == @r2
      end
      
    end

    describe "#generation" do
      
      it "should find all nodes in the same generation as this one for a root node" do
        @r1.generation.should == [@r1, @r2, @r3]
      end
      
      it "should find all nodes in the same generation as this one" do
        @r1c1.generation.should == [@r1c1, @r1c2, @r1c3]
      end
      
    end
    
    describe "#siblings" do
      
      it "should find all sibling nodes for a root node" do
        @r1.siblings.should == [@r2, @r3]
      end
      
      it "should find all sibling nodes for a child node" do
        @r1c1.siblings.should == [@r1c2, @r1c3]
      end
      
    end
    
    describe "#descendants" do
      
      it "should find all descendants of this node" do
        @r1.descendants.should == [@r1c1, @r1c1s1, @r1c2, @r1c2s1, @r1c2s2, @r1c2s2m1, @r1c2s3, @r1c3]
      end
    end
    
    describe "#family" do
      
      it "should combine descendants, self and siblings"
      
    end
    
    describe "#ancestors" do
      
      it "should be blank"
      
    end
    
    describe "#kin" do
      
      it "should find the patriarch and all its descendents"
      
    end

  end

  describe @model, "with acts_as_nested_set" do
  
    it "should add a new root node if the parent is not set" do
      without_changing_the_database do
        @instance = @model.create!(valid_attributes)
        @instance.parent_id.should be_nil
        @instance.left.should == 1
        @instance.right.should == 2
      end
    end
  
    it "should add a new root node if the parent is not set and there already are some root nodes" do
      without_changing_the_database do
        @model.create!(valid_attributes)
        @model.create!(valid_attributes)
        @instance = @model.create!(valid_attributes)
        @instance.reload
        @instance.parent_id.should be_nil
        @instance.left.should == 5
        @instance.right.should == 6
      end
    end
  
    it "should append a child node to a parent" do
      without_changing_the_database do
        @parent = @model.create!(valid_attributes)
        @parent.left.should == 1
        @parent.right.should == 2
      
        @instance = @model.create!(valid_attributes(:parent => @parent))
        
        @parent.reload
        
        @instance.parent.should == @parent

        @instance.left.should == 2
        @instance.right.should == 3

        @parent.left.should == 1
        @parent.right.should == 4
      end
    end
    
    it "should rollback changes if the save is not successfull for some reason" do
      without_changing_the_database do
        @parent = @model.create!(valid_attributes)
        @parent.left.should == 1
        @parent.right.should == 2
      
        @instance = @model.create(invalid_attributes(:parent => @parent))
        @instance.should be_a_new_record
        
        @parent.reload

        @parent.left.should == 1
        @parent.right.should == 2
      end
    end
    
    it "should append a child node to a parent and shift other nodes out of the way" do
      without_changing_the_database do
        @root1 = @model.create!(valid_attributes)
        @root2 = @model.create!(valid_attributes)
        
        @root1.left.should == 1
        @root1.right.should == 2
        @root2.left.should == 3
        @root2.right.should == 4
        
        @child1 = @model.create!(valid_attributes(:parent => @root1))
        
        @root1.reload
        @root2.reload
        
        @root1.left.should == 1
        @root1.right.should == 4
        @root2.left.should == 5
        @root2.right.should == 6
        
        @child1.left.should == 2
        @child1.right.should == 3
        
        @child2 = @model.create!(valid_attributes(:parent => @root1))
        
        @root1.reload
        @root2.reload
        @child1.reload
        
        @root1.left.should == 1
        @root1.right.should == 6
        @root2.left.should == 7
        @root2.right.should == 8
        
        @child1.left.should == 2
        @child1.right.should == 3
        
        @child2.left.should == 4
        @child2.right.should == 5
        
        @subchild1 = @model.create!(valid_attributes(:parent => @child2))
        
        @root1.reload
        @root2.reload
        @child1.reload
        @child2.reload
        
        @root1.left.should == 1
        @root1.right.should == 8
        @root2.left.should == 9
        @root2.right.should == 10
        
        @child1.left.should == 2
        @child1.right.should == 3
        
        @child2.left.should == 4
        @child2.right.should == 7
        
        @subchild1.left.should == 5
        @subchild1.right.should == 6
        
        @subchild2 = @model.create!(valid_attributes(:parent => @child1))
        
        @root1.reload
        @root2.reload
        @child1.reload
        @child2.reload
        @subchild1.reload
        
        @root1.left.should == 1
        @root1.right.should == 10
        @root2.left.should == 11
        @root2.right.should == 12
        
        @child1.left.should == 2
        @child1.right.should == 5
        
        @child2.left.should == 6
        @child2.right.should == 9

        @subchild1.left.should == 7
        @subchild1.right.should == 8
        
        @subchild2.left.should == 3
        @subchild2.right.should == 4
      end
    end
  
  end

end