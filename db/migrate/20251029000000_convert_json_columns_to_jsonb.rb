class ConvertJsonColumnsToJsonb < ActiveRecord::Migration[8.0]
  def up
    # Convert filter_params from text to jsonb
    add_column :filters, :filter_params_jsonb, :jsonb, default: {}
    execute <<-SQL
      UPDATE filters
      SET filter_params_jsonb = CASE
        WHEN filter_params IS NULL OR filter_params = '' THEN '{}'::jsonb
        ELSE filter_params::jsonb
      END
    SQL
    change_column_default :filters, :filter_params_jsonb, nil

    # Convert filter_types from text to jsonb
    add_column :filters, :filter_types_jsonb, :jsonb, default: []
    execute <<-SQL
      UPDATE filters
      SET filter_types_jsonb = CASE
        WHEN filter_types IS NULL OR filter_types = '' THEN '[]'::jsonb
        ELSE filter_types::jsonb
      END
    SQL
    change_column_default :filters, :filter_types_jsonb, nil

    # Convert date_range from text to jsonb (nullable)
    add_column :filters, :date_range_jsonb, :jsonb
    execute <<-SQL
      UPDATE filters
      SET date_range_jsonb = CASE
        WHEN date_range IS NULL OR date_range = '' THEN NULL
        ELSE date_range::jsonb
      END
    SQL

    # Remove old text columns
    remove_column :filters, :filter_params
    remove_column :filters, :filter_types
    remove_column :filters, :date_range

    # Rename jsonb columns to original names
    rename_column :filters, :filter_params_jsonb, :filter_params
    rename_column :filters, :filter_types_jsonb, :filter_types
    rename_column :filters, :date_range_jsonb, :date_range

    # Add indexes for jsonb columns for better query performance
    add_index :filters, :filter_params, using: :gin
    add_index :filters, :filter_types, using: :gin
  end

  def down
    # Remove indexes
    remove_index :filters, :filter_types
    remove_index :filters, :filter_params

    # Rename jsonb columns
    rename_column :filters, :filter_params, :filter_params_jsonb
    rename_column :filters, :filter_types, :filter_types_jsonb
    rename_column :filters, :date_range, :date_range_jsonb

    # Add back text columns
    add_column :filters, :filter_params, :text
    add_column :filters, :filter_types, :text
    add_column :filters, :date_range, :text

    # Convert jsonb back to text
    execute <<-SQL
      UPDATE filters
      SET filter_params = filter_params_jsonb::text
      WHERE filter_params_jsonb IS NOT NULL
    SQL

    execute <<-SQL
      UPDATE filters
      SET filter_types = filter_types_jsonb::text
      WHERE filter_types_jsonb IS NOT NULL
    SQL

    execute <<-SQL
      UPDATE filters
      SET date_range = date_range_jsonb::text
      WHERE date_range_jsonb IS NOT NULL
    SQL

    # Remove jsonb columns
    remove_column :filters, :filter_params_jsonb
    remove_column :filters, :filter_types_jsonb
    remove_column :filters, :date_range_jsonb
  end
end
