require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/nested_set_behavior'

class Directory < ActiveRecord::Base
  acts_as_nested_set :left => :lft, :right => :rgt
  
  validates_presence_of :name
end

describe Directory do
  
  def invalid_attributes(options = {})
    return {  }.merge(options)
  end
  
  def valid_attributes(options = {})
    $directory_no = $directory_no ? $directory_no + 1 : 0
    return { :name => "directory#{$directory_no}" }.merge(options)
  end
  
  before do
    @model = Directory
    @instance = @model.new
  end
  
  it_should_behave_like "all nested set models"
  
  it "should throw an error when attempting to assign lft directly" do
    lambda {
      @instance.lft = 42
    }.should raise_error(EvenBetterNestedSet::IllegalAssignmentError)
    @instance.lft.should_not == 42
  end
  
  it "should throw an error when attempting to assign rgt directly" do
    lambda {
      @instance.rgt = 42
    }.should raise_error(EvenBetterNestedSet::IllegalAssignmentError)
    @instance.rgt.should_not == 42
  end
  
  it "should throw an error when mass assigning to lft" do
    lambda {
      @model.new(valid_attributes(:lft => 1))
    }.should raise_error(EvenBetterNestedSet::IllegalAssignmentError)
  end
  
  it "should throw an error when mass assigning to rgt" do
    lambda {
      @model.new(valid_attributes(:rgt => 1))
    }.should raise_error(EvenBetterNestedSet::IllegalAssignmentError)
  end
  
end
