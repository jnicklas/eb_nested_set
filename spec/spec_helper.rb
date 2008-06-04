$TESTING=true
$:.push File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'active_record'

require 'even_better_nested_set'

require 'spec'

# change this if sqlite is unavailable
dbconfig = {
  :adapter => 'sqlite3',
  :database => File.join(File.dirname(__FILE__), 'db', 'test.sqlite3')
}

ActiveRecord::Base.establish_connection(dbconfig)
ActiveRecord::Migration.verbose = false

class Directory < ActiveRecord::Base
  acts_as_nested_set
end

class TestMigration < ActiveRecord::Migration
  def self.up
    create_table :directories, :force => true do |t|
      t.column :left, :integer
      t.column :right, :integer
      t.column :parent_id, :integer
      t.column :name, :string
    end
  end

  def self.down
    drop_table :directories
  rescue
    nil
  end
end

def without_changing_the_database
  ActiveRecord::Base.transaction do
    yield
    raise ActiveRecord::Rollback
  end
end

TestMigration.down
TestMigration.up