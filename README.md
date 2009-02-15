# EvenBetterNestedSet

A nested set is a datastruture in a database, sort of like a tree, but unlike a tree it allows you to find all descendants of a node with a single query. Loading a deeply nested structure with nested sets is therefore a lot more efficient than using a tree. So what's the disadvantage? Nested sets are a lot harder to maintain, since inserting and moving records requires management and it is easy to corrupt the dataset. Enter: EvenBetterNestedSet. Amount of micromanaging you need to do: 0. EvenBetterNestedSet does it all for you.

## Declaring nested sets

This is how you declare a nested set:

    class Directory < ActiveRecord::Base
    
      acts_as_nested_set
    
    end
    
The directories table should have the columns 'parent_id', 'left' and 'right'.

Now just set the parent to wherever you want your node to be located and EvenBetterNestedSet will do the rest for you.
    
    d = Directory.new
    
    d.children.create!(:name => 'blah')
    d.children.create!(:name => 'gurr')
    d.children.create!(:name => 'doh')
    
    d.bounds #=> 1..8
    d.children[1].bounds #=> 4..5
    d.children[1].name #=> 'gurr'
    d.children[1].parent #=> d
    
    c = Directory.create!(:name => 'test', :parent => d.directory[1]

## Finding with nested sets

EvenBetterNestedSet will not automatically cache children for you, because it assumes that this is not always the preferred behaviour. If you want to cache children to a nested set, just do:

    d = Directory.find(42)
    d.cache_nested_set
    
or more conveniently:

    d = Directory.find_with_nested_set(42)