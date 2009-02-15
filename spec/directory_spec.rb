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
  end
  
  it_should_behave_like "all nested set models"
  
end
