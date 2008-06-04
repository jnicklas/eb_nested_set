EvenBetterNestedSet
===================


this is an alternative to ActsAsNestedSet, and BetterNestedSet which is just a little bit less stupid.

    class Directory < ActiveRecord::Base
    
      acts_as_nested_set
    
    end
    
    d = Directory.new
    
    d.children.create!(:name => 'blah')
    d.children.create!(:name => 'gurr')
    d.children.create!(:name => 'doh')
    
    d.bounds #=> 1..8
    d.children[1].bounds #=> 4..5
    d.children[1].name #=> 'gurr'
    d.children[1].parent #=> d
    
    c = Directory.create!(:name => 'test', :parent => d.directory[1]
    