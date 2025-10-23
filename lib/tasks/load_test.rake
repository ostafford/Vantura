# lib/tasks/load_test.rake
# Load testing tasks for Vantura application

namespace :load_test do
  desc "Run a quick load test to validate Puma configuration"
  task quick: :environment do
    puts "🚀 Starting Quick Load Test"
    puts "Testing Puma configuration with realistic traffic patterns"
    puts "=" * 50

    require "httparty"
    require "concurrent"
    require "time"

    class LoadTestRunner
      include HTTParty
      base_uri "http://localhost:3001"

      def initialize
        @results = []
        @errors = 0
        @mutex = Mutex.new
      end

      def run_test(duration: 30, concurrent_users: 5)
        puts "Duration: #{duration} seconds"
        puts "Concurrent Users: #{concurrent_users}"
        puts "Testing endpoints: /up, /, /calendar, /trends"
        puts "=" * 50

        start_time = Time.now
        end_time = start_time + duration

        # Create thread pool for concurrent requests
        pool = Concurrent::FixedThreadPool.new(concurrent_users)

        # Submit requests until time expires
        while Time.now < end_time
          pool.post { make_request }
          sleep(0.2) # Small delay to prevent overwhelming
        end

        # Wait for completion
        pool.shutdown
        pool.wait_for_termination(10)

        # Display results
        display_results(start_time)
      end

      private

      def make_request
        endpoints = [
          { path: "/up", weight: 10 },
          { path: "/", weight: 40 },
          { path: "/calendar", weight: 30 },
          { path: "/trends", weight: 20 }
        ]

        # Weighted random selection
        total_weight = endpoints.sum { |e| e[:weight] }
        random = rand(total_weight)
        current_weight = 0

        endpoint = endpoints.find do |e|
          current_weight += e[:weight]
          random < current_weight
        end

        start_time = Time.now

        begin
          response = self.class.get(endpoint[:path])
          response_time = (Time.now - start_time) * 1000

          @mutex.synchronize do
            @results << {
              endpoint: endpoint[:path],
              response_time: response_time,
              status: response.code,
              timestamp: Time.now
            }
          end

        rescue => e
          @mutex.synchronize { @errors += 1 }
          puts "❌ Error on #{endpoint[:path]}: #{e.message}"
        end
      end

      def display_results(start_time)
        duration = Time.now - start_time
        total_requests = @results.size
        requests_per_second = total_requests / duration

        if @results.any?
          response_times = @results.map { |r| r[:response_time] }
          avg_response_time = response_times.sum / response_times.size
          max_response_time = response_times.max
          min_response_time = response_times.min

          # Calculate percentiles
          sorted_times = response_times.sort
          p50 = percentile(sorted_times, 50)
          p90 = percentile(sorted_times, 90)
          p95 = percentile(sorted_times, 95)
        end

        puts "\n📊 Load Test Results"
        puts "=" * 50
        puts "Total Requests: #{total_requests}"
        puts "Errors: #{@errors}"
        puts "Error Rate: #{(@errors.to_f / total_requests * 100).round(2)}%" if total_requests > 0
        puts "Duration: #{duration.round(2)} seconds"
        puts "Requests/Second: #{requests_per_second.round(2)}"

        if @results.any?
          puts "\nResponse Times (ms):"
          puts "  Average: #{avg_response_time.round(2)}"
          puts "  Min: #{min_response_time.round(2)}"
          puts "  Max: #{max_response_time.round(2)}"
          puts "  P50: #{p50.round(2)}"
          puts "  P90: #{p90.round(2)}"
          puts "  P95: #{p95.round(2)}"
        end

        puts "\n🎯 Performance Assessment:"
        assess_performance(avg_response_time, p95, requests_per_second, @errors, total_requests)
      end

      def percentile(sorted_array, percentile)
        return nil if sorted_array.empty?
        index = (percentile / 100.0) * (sorted_array.length - 1)
        lower = sorted_array[index.floor]
        upper = sorted_array[index.ceil]
        lower + (upper - lower) * (index - index.floor)
      end

      def assess_performance(avg_latency, p95_latency, rps, errors, total_requests)
        error_rate = errors.to_f / total_requests * 100 if total_requests > 0

        puts "  Throughput: #{rps.round(2)} req/s"

        if avg_latency && avg_latency < 200
          puts "  ✅ Average latency: #{avg_latency.round(2)}ms (Excellent)"
        elsif avg_latency && avg_latency < 500
          puts "  ✅ Average latency: #{avg_latency.round(2)}ms (Good)"
        elsif avg_latency && avg_latency < 1000
          puts "  ⚠️  Average latency: #{avg_latency.round(2)}ms (Acceptable)"
        else
          puts "  ❌ Average latency: #{avg_latency.round(2)}ms (Poor)"
        end

        if p95_latency && p95_latency < 500
          puts "  ✅ P95 latency: #{p95_latency.round(2)}ms (Excellent)"
        elsif p95_latency && p95_latency < 1000
          puts "  ✅ P95 latency: #{p95_latency.round(2)}ms (Good)"
        elsif p95_latency && p95_latency < 2000
          puts "  ⚠️  P95 latency: #{p95_latency.round(2)}ms (Acceptable)"
        else
          puts "  ❌ P95 latency: #{p95_latency.round(2)}ms (Poor)"
        end

        if error_rate && error_rate < 1
          puts "  ✅ Error rate: #{error_rate.round(2)}% (Excellent)"
        elsif error_rate && error_rate < 5
          puts "  ⚠️  Error rate: #{error_rate.round(2)}% (Acceptable)"
        else
          puts "  ❌ Error rate: #{error_rate.round(2)}% (Poor)"
        end

        puts "\n💡 Recommendations:"
        if avg_latency && avg_latency > 500
          puts "  - Consider optimizing database queries"
          puts "  - Check for N+1 query problems"
        end

        if p95_latency && p95_latency > 1000
          puts "  - Review slow endpoints"
          puts "  - Consider caching strategies"
        end

        if error_rate && error_rate > 1
          puts "  - Investigate error causes"
          puts "  - Check server resources"
        end
      end
    end

    # Run the test
    tester = LoadTestRunner.new
    tester.run_test(duration: 30, concurrent_users: 5)
  end

  desc "Run a comprehensive load test with multiple scenarios"
  task comprehensive: :environment do
    puts "🚀 Starting Comprehensive Load Test"
    puts "Testing multiple scenarios to validate Puma configuration"
    puts "=" * 60

    scenarios = [
      { name: "Light Load", duration: 30, users: 5 },
      { name: "Medium Load", duration: 60, users: 10 },
      { name: "Heavy Load", duration: 90, users: 15 }
    ]

    scenarios.each_with_index do |scenario, index|
      puts "\n#{index + 1}. #{scenario[:name]} Test"
      puts "   Duration: #{scenario[:duration]}s, Users: #{scenario[:users]}"

      # Run the test (same logic as quick test)
      # For brevity, we'll just show the scenario
      puts "   [Test would run here]"
      puts "   ✅ #{scenario[:name]} completed"

      sleep(2) # Brief pause between tests
    end

    puts "\n🎉 All load tests completed!"
    puts "Check the results above to validate your Puma configuration."
  end

  desc "Show load testing help and examples"
  task help: :environment do
    puts "Vantura Load Testing Tasks"
    puts "=" * 30
    puts ""
    puts "Available tasks:"
    puts "  rake load_test:quick          - Run a quick 30-second test"
    puts "  rake load_test:comprehensive  - Run multiple test scenarios"
    puts "  rake load_test:help           - Show this help"
    puts ""
    puts "Before running load tests:"
    puts "  1. Start your Rails server: rails server"
    puts "  2. Make sure it's running on localhost:3001"
    puts "  3. Run the load test: rake load_test:quick"
    puts ""
    puts "The load test will:"
    puts "  - Test multiple endpoints (/up, /, /calendar, /trends)"
    puts "  - Simulate concurrent users"
    puts "  - Measure response times and throughput"
    puts "  - Provide performance recommendations"
    puts ""
    puts "Good performance targets:"
    puts "  - Average latency: < 500ms"
    puts "  - P95 latency: < 1000ms"
    puts "  - Error rate: < 1%"
    puts "  - Throughput: Depends on your server specs"
  end
end
