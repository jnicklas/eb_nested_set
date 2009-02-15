$TESTING=true
$:.push File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'active_record'
# require 'ruby-debug' # Slows down the tests massively

require 'eb_nested_set'

require 'spec'

# change this if sqlite is unavailable
dbconfig = case ENV["DB"]
  when "postgresql"
    {
      :adapter => 'postgresql',
      :database => 'even_better_nested_set_test',
      :host => '127.0.0.1'
    }
  when "mysql"
    {
      :adapter => 'mysql',
      :database => 'even_better_nested_set_test',
      :host => '127.0.0.1'
    }
  else
    {
      :adapter => 'sqlite3',
      :database => File.join(File.dirname(__FILE__), 'db', 'test.sqlite3')
    }
  end

ActiveRecord::Base.establish_connection(dbconfig)
ActiveRecord::Migration.verbose = false

def show_model_variables_for(context, model)
  context.instance_variables.sort.each do |i|
    m = eval(i)
    if m.is_a?(model)
      m.reload
      puts "#{i.ljust(8)}\t#{m.left}\t#{m.right}\t#{m.name}"
    end
  end
end

#ActiveRecord::Base.logger = Logger.new(STDOUT)


class TestMigration < ActiveRecord::Migration
  def self.up
    create_table :directories, :force => true do |t|
      t.column :lft, :integer
      t.column :rgt, :integer
      t.column :parent_id, :integer
      t.column :name, :string
    end
    
    create_table :employees, :force => true do |t|
      t.column :left, :integer
      t.column :right, :integer
      t.column :parent_id, :integer
      t.column :name, :string
      t.column :company_id, :integer
    end
  end

  def self.down
    drop_table :directories
    drop_table :employees
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
