puts "*" * 80
puts "After"
puts "*" * 80
p run_context.resource_collection.map(&:to_s)
