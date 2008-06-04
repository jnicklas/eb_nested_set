# This is specific for GibberishAttributes being used as a Rails plugin

require File.join(File.dirname(__FILE__), 'lib', 'gibberish_attributes')

ActiveRecord::Base.send(:include, BetterNestedSet)