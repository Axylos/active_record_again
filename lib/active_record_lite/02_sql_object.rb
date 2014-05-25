require_relative 'db_connection'
require_relative '01_mass_object'
require 'active_support/inflector'

class MassObject
  def self.parse_all(results)
    results.map { |params| self.new(params) }
  end
end

class SQLObject < MassObject
  def self.columns

    cols = DBConnection.instance.execute2(<<-SQL)
    SELECT *
    FROM #{table_name}

    SQL
    cols.first.each do |col_name|
      define_method("#{col_name}") do
        attributes[col_name.to_sym]
      end
      define_method("#{col_name}=") do |col_val|
        attributes[col_name.to_sym] = col_val
      end
    end
    cols.first.map!(&:to_sym)
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.to_s.tableize
  end

  def self.all
    object_hash = DBConnection.instance.execute(<<-SQL)

    SELECT #{table_name}.*
    FROM #{table_name}

    SQL
    self.parse_all object_hash
  end

  def self.find(id)
    params = DBConnection.instance.execute(<<-SQL, id)

    SELECT *
    FROM #{table_name}
    WHERE id = ?

    SQL
    (parse_all params).first
  end

  def attributes
    @attributes ||= {}
  end

  def insert
    col_names = attributes.keys
    col_line = col_names.join(", ")
    vals = attribute_values
    var_line = (["?"] * col_names.length).join(", ")

    DBConnection.instance.execute(<<-SQL, vals)
    INSERT INTO
    #{self.class.table_name} (#{col_line})
    VALUES
    (#{var_line})

    SQL

    new_id = DBConnection.last_insert_row_id
    attributes[:id] = new_id
  end

  def initialize(params={})
    cols = self.class.columns

    params.each do |attr_name, value|
      unless cols.include? attr_name.to_sym
        raise "unknown attribute '#{attr_name}'"
      end
      attributes[attr_name.to_sym] = value
    end
  end

  def save
    attributes[:id].nil? ? insert : update
  end

  def update
   set_line = attributes.map { |attr, val| "#{attr} = ? " }.join(", ")

    DBConnection.include.execute(<<-SQL, *attribute_values)

    UPDATE #{ self.class.table_name }
    SET #{set_line}
    WHERE
    id = #{ attributes[:id].to_i}

    SQL

  end

  def attribute_values
    attributes.values
  end
end
