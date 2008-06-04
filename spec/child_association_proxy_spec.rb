require File.dirname(__FILE__) + '/spec_helper'

describe EvenBetterNestedSet::ChildAssociationProxy do
  
  it "should remember its parent" do
    without_changing_the_database do
      @parent = Directory.create!(:name => :john)
      @proxy = EvenBetterNestedSet::ChildAssociationProxy.new(@parent)
      @proxy.parent.should == @parent
    end
  end
  
end