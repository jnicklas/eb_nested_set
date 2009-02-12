require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/nested_set_behavior'

class Employee < ActiveRecord::Base
  acts_as_nested_set :scope => :company, :left => 'left', :right => 'right'
  
  validates_presence_of :name
end

describe Employee, "with nested sets for two different companies" do
  before do
    # Company 1...
    Employee.with_options :company_id => 1 do |c1|
      @c1_1 = c1.create!(:name => "Company 1 - 1")
      @c1_2 = c1.create!(:name => "Company 1 - 2")
      
      @c1_11 = c1.create!(:name => "Company 1 - 11", :parent => @c1_1)
      @c1_12 = c1.create!(:name => "Company 1 - 12", :parent => @c1_1)
      
      @c1_111 = c1.create!(:name => "Company 1 - 111", :parent => @c1_11)
    end
    
    # Company 2...
    Employee.with_options :company_id => 2 do |c2|
      @c2_1 = c2.create!(:name => "Company 2 - 1")
      @c2_11 = c2.create!(:name => "Company 2 - 11", :parent => @c2_1)
    end
  end
  
  after do
    Employee.delete_all
  end
  
  it "should not allow a new employee in one company to be a child of an employee in the other company, when parent is assigned to" do
    @employee = Employee.create(:company_id => 1, :parent => @c2_11)
    @employee.errors[:parent_id].should_not be_nil
  end
  
  it "should not allow a new employee in one company to be a child of an employee in the other company, when parent_id is assigned to" do
    @employee = Employee.create(:company_id => 1, :parent_id => @c2_11.id)
    @employee.errors[:parent_id].should_not be_nil
  end
  
  it "should not allow an existing employee in one company to become a child of an employee in the other company, when parent is assigned to" do
    @c1_11.parent = @c2_11
    @c1_11.save
    @c1_11.errors[:parent_id].should_not be_nil
  end
  
  it "should not allow an existing employee in one company to become a child of an employee in the other company, when parent_id is assigned to" do
    @c1_11.parent_id = @c2_11.id
    @c1_11.save
    @c1_11.errors[:parent_id].should_not be_nil
  end
  
  it "should keep the tree for company 1 and for company 2 entirely disjoint" do
    c1_tree = (@c1_1.family + @c1_2.family).flatten
    c2_tree = @c2_1.family
    
    (c1_tree & c2_tree).should be_empty
  end
  
  it "should return the correct descendants when retrieving via a database query" do
    @c1_1.descendants.should == [@c1_11, @c1_111, @c1_12]
    @c1_2.descendants.should == []
    @c2_1.descendants.should == [@c2_11]
  end
  
  it "should return the correct levels when retrieving via a database query" do
    @c1_1.family.map { |d| d.level }.should == [0, 1, 2, 1]
    @c1_2.family.map { |d| d.level }.should == [0]
    @c2_1.family.map { |d| d.level }.should == [0, 1]
  end
end
