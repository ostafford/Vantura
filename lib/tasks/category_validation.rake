namespace :category do
  desc "Validate category parent relationships and diagnose association issues"
  task validate_parents: :environment do
    puts "\n" + "="*80
    puts "Category Parent Relationship Validation"
    puts "="*80 + "\n"

    # Check database column type
    column_info = Category.columns.find { |c| c.name == "parent_id" }
    puts "Database Column Info:"
    puts "  Column name: #{column_info.name}"
    puts "  Column type: #{column_info.type}"
    puts "  SQL type: #{column_info.sql_type}"
    puts "  Nullable: #{column_info.null}"
    puts ""

    # Check sample data
    categories_with_parents = Category.where.not(parent_id: nil).limit(10)
    puts "Sample Categories with Parents (#{categories_with_parents.count} found):"
    puts ""

    categories_with_parents.each do |cat|
      puts "  Category: #{cat.name} (#{cat.up_id})"
      puts "    Database ID: #{cat.id} (integer)"
      puts "    Up ID: #{cat.up_id} (string)"
      puts "    parent_id value: #{cat.parent_id.inspect} (#{cat.parent_id.class})"
      
      # Try to access parent via association
      begin
        parent = cat.parent
        if parent
          puts "    ✓ Association works: parent = #{parent.name} (#{parent.up_id}, id: #{parent.id})"
        else
          puts "    ✗ Association returned nil"
          
          # Try manual lookup
          manual_parent = Category.find_by(up_id: cat.parent_id)
          if manual_parent
            puts "    → Manual lookup found: #{manual_parent.name} (#{manual_parent.up_id}, id: #{manual_parent.id})"
            puts "    → DIAGNOSIS: parent_id stores up_id (string), but belongs_to expects id (integer)"
            puts "    → FIX: Add primary_key: 'up_id' to belongs_to association"
          else
            puts "    ✗ Manual lookup also failed - parent category doesn't exist"
          end
        end
      rescue => e
        puts "    ✗ Association error: #{e.class} - #{e.message}"
        puts "    → This confirms the association is broken"
        
        # Try manual lookup
        begin
          manual_parent = Category.find_by(up_id: cat.parent_id)
          if manual_parent
            puts "    → Manual lookup found: #{manual_parent.name} (#{manual_parent.up_id})"
            puts "    → CONFIRMED: Association broken due to type mismatch"
          end
        rescue => e2
          puts "    → Manual lookup also failed: #{e2.message}"
        end
      end
      puts ""
    end

    # Check if any categories reference non-existent parents
    puts "Data Integrity Check:"
    all_parent_ids = Category.pluck(:parent_id).compact.uniq
    existing_up_ids = Category.pluck(:up_id)
    missing_parents = all_parent_ids - existing_up_ids
    
    if missing_parents.any?
      puts "  ⚠️  Categories referencing non-existent parents: #{missing_parents.inspect}"
    else
      puts "  ✓ All parent_id values reference existing categories"
    end
    puts ""

    # Test the association query
    puts "Association Query Test:"
    test_category = categories_with_parents.first
    if test_category
      puts "  Testing with: #{test_category.name} (#{test_category.up_id})"
      puts "  parent_id value: #{test_category.parent_id.inspect}"
      
      # Show what SQL would be generated
      begin
        parent = test_category.parent
        if parent
          puts "  ✓ Association query succeeded"
        else
          puts "  ✗ Association query returned nil"
          puts "  → Expected SQL: SELECT * FROM categories WHERE id = '#{test_category.parent_id}'"
          puts "  → But should be: SELECT * FROM categories WHERE up_id = '#{test_category.parent_id}'"
        end
      rescue => e
        puts "  ✗ Association query failed: #{e.message}"
      end
    end
    puts ""

    puts "="*80
    puts "Validation Complete"
    puts "="*80 + "\n"
  end
end

