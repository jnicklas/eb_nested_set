require File.dirname(__FILE__) + '/spec_helper'

describe ActiveRecord::Base, 'model with acts_as_nested_set' do
  
  before do
    @directory = Directory.create!(:name => 'jonas', :left => 1, :right => 2, :parent_id => nil)
  end
  
  after do
    @directory.destroy
  end
  
  it "should be valid" do
    @directory.should be_valid
  end
  
  it "should not be valid if left is not set" do
    @directory.left = nil
    @directory.should_not be_valid
  end
  
  it "should not be valid if right is not set" do
    @directory.right = nil
    @directory.should_not be_valid
  end
  
  it "should not be valid if right is greater than left" do
    @directory.left = 2
    @directory.right = 1
    @directory.should_not be_valid
  end
  
  it "should not be valid if the difference between left and right is even" do
    @directory.left = 1
    @directory.right = 3
    @directory.should_not be_valid
    
    @directory.left = 5
    @directory.right = 7
    @directory.should_not be_valid
  end
  
  it "should add a new root node if the parent is not set" do
    @directory.destroy
    without_changing_the_database do
      @directory = Directory.create!(:name => "jonas")
      @directory.parent_id.should be_nil
      @directory.left.should == 1
      @directory.right.should == 2
    end
  end
  
  it "should add a new root node if the parent is not set and there already are some root nodes" do
    @directory.destroy
    without_changing_the_database do
      Directory.create!(:name => "blah")
      Directory.create!(:name => "gurr")
      @directory = Directory.create!(:name => "jonas")
      @directory.parent_id.should be_nil
      @directory.left.should == 5
      @directory.right.should == 6
    end
  end
  
  it "should append a child node to a parent" do
    @directory.destroy
    without_changing_the_database do
      @parent = Directory.create!(:name => "blah")
      @parent.left.should == 1
      @parent.right.should == 2
      
      @directory = Directory.create!(:name => "jonas", :parent => @parent)
      
    end
  end
  
  describe '#bounds' do
    
    it "should return a range, from left to right" do
      @directory.left = 3
      @directory.right = 6
      @directory.bounds.should == (3..6)
    end
    
  end
  
  #describe '#parent' do
  #  
  #  it "should fetch the parent from the db, if it has not been cached" do
  #    without_changing_the_database do
  #      @parent = Directory.create!(:name => 'jonas')
  #      @directory.save!
  #      @directory.reload
  #      @directory.parent.id == @parent.id
  #    end
  #  end
  #  
  #end
  
  
end