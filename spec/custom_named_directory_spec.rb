require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/nested_set_behavior'

class CustomNamedDirectory < ActiveRecord::Base
  acts_as_nested_set :parent_column => :baz_id
  
  validates_presence_of :name
end

describe CustomNamedDirectory do
  include AttributeHelper
  
  before do
    @model = CustomNamedDirectory
  end
  
  it_should_behave_like "all nested set models"
  
end
