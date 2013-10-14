module ActiveRecord::Import::PostgreSQLAdapter
  include ActiveRecord::Import::ImportSupport

  NO_MAX_PACKET = 0

  def next_value_for_sequence(sequence_name)
    %{nextval('#{sequence_name}')}
  end

  def insert_many( sql, values, *args ) # :nodoc:
    # the number of inserts default
    number_of_inserts = 0

    base_sql, post_sql = if sql.is_a?( String )
      [ sql, '' ]
    elsif sql.is_a?( Array )
      [ sql.shift, sql ]
    end

    sql_size =  base_sql.size + post_sql.size

    # the number of bytes the requested insert statement values will take up
    values_in_bytes = values.sum {|value| value.bytesize }

    # the number of bytes (commas) it will take to comma separate our values
    comma_separated_bytes = values.size-1

    # the total number of bytes required if this statement is one statement
    total_bytes = sql_size + values_in_bytes + comma_separated_bytes

    max = max_allowed_packet

    selector_sql = args.second if args.second.present?
    table_name = args.third if args.third.present?

    # if we can insert it all as one statement
    sql2insert = ""
    if NO_MAX_PACKET == max or total_bytes < max
      number_of_inserts += 1
      if selector_sql.present? && table_name.present?
        sql2insert << generate_sql_for_insert(post_sql, selector_sql, base_sql, values, table_name)
      end
      insert( sql2insert, args.first )
    else
      value_sets = ::ActiveRecord::Import::ValueSetsBytesParser.parse(values,
        :reserved_bytes => sql_size,
        :max_bytes => max)
      value_sets.each do |values|
        number_of_inserts += 1
        if selector_sql.present? && table_name.present?
          sql2insert << generate_sql_for_insert(post_sql, selector_sql, base_sql, values, table_name)
        end
        insert( sql2insert, args.first )
      end
    end
    number_of_inserts
  end

  def generate_sql_for_insert(post_sql, selector_sql, base_sql, values, table_name)
    sql2insert = ""

    base_sql.slice!(' VALUES ')
    values.each_with_index do |value, index|
      # post_sql = UPDATE table SET field = 'C', field2 = 'D';
      # base_sql = INSERT INTO table (field, field2)
      # value = ('C', 'D') WHERE NOT EXISTS ( SELECT 1 FROM table WHERE dup_field = 'A' AND dup_field2 = 'B');

      v = value[1...-1] # Remove opening and closing brackets from value
      sql2insert << post_sql[index] + selector_sql[index] + "; " + base_sql + " SELECT " + v + " WHERE NOT EXISTS ( SELECT 1 FROM #{table_name} #{selector_sql[index]} ); "
    end
    return sql2insert

  end

  # For Postgres, this is actually a PRE Insert statement.
  # Generate an array of update statements to be used with the selector_sql. If no records
  # are found with the selector_sql, the update will just fail silently with no side effect.
  def sql_for_on_duplicate_key_update( table_name, *args ) # :nodoc:
    sql = []
    arg = args.first
    if arg.is_a?( Array )
      column_names = args[1]
      array_of_attributes = args[2]
      column_hash = Hash[column_names.map.with_index.to_a]

      array_of_attributes.each do |record|
        record_updates = []
        results = arg.map do |column|
          field_index = column_hash[column]
          field_value = record[field_index]

          qc = quote_column_name( column )
          "#{qc}= '#{field_value}'"
        end

        record_sql = results.present? ? "UPDATE #{table_name} SET " + results.join(',') + " " : ""
        sql << record_sql
      end

    else
      raise ArgumentError.new( "Expected Array" )
    end

    sql
  end

  def selector_sql( column_names, array_of_attributes, options )
    selectors = []

    if options[:on_duplicate_key_update].present? && options[:index_keys].present?
      index_key_fields = options[:index_keys]
      column_hash = Hash[column_names.map.with_index.to_a]

      array_of_attributes.each do |record|
        record_selectors = []
        index_key_fields.each do |field|
          field_index = column_hash[field]
          field_value = record[field_index]

          if field_value.eql?(nil)
            record_selectors << "#{field.to_s} IS NULL"
          elsif field_value.present?
            record_selectors << "#{field.to_s} = '#{field_value}'"
          end
        end

        record_sql = record_selectors.present? ? "WHERE " + record_selectors.join(" AND ") : ""
        selectors << record_sql
      end
    end

    # return an array of strings like "WHERE field1 = 2 AND field2 = 1 AND field3 IS NULL"
    return selectors
  end

end
