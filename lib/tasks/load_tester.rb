#!/usr/bin/env ruby
# Load Testing Script for Vantura Application
# Tests realistic traffic patterns to validate Puma configuration

require "httparty"
require "concurrent"
require "json"
require "time"

class VanturaLoadTester
  include HTTParty
  base_uri "http://localhost:3001"

  def initialize
    @results = {
      requests: 0,
      errors: 0,
      total_time: 0,
      response_times: [],
      error_details: []
    }
    @mutex = Mutex.new
  end

  # Test endpoints based on your routes
  ENDPOINTS = [
    { path: "/up", method: :get, weight: 10 },                    # Health check
    { path: "/", method: :get, weight: 40 },                      # Dashboard
    { path: "/calendar", method: :get, weight: 25 },              # Calendar
    { path: "/trends", method: :get, weight: 15 },                # Trends
    { path: "/transactions/all", method: :get, weight: 10 }       # Transactions
  ].freeze

  def run_load_test(duration: 60, concurrent_users: 10, warmup: 10)
    puts "🚀 Starting Vantura Load Test"
    puts "=" * 50
    puts "Duration: #{duration} seconds"
    puts "Concurrent Users: #{concurrent_users}"
    puts "Warmup Requests: #{warmup}"
    puts "=" * 50

    # Warmup phase
    puts "\n🔥 Warming up application..."
    warmup_requests(warmup)

    # Main load test
    puts "\n📊 Running load test..."
    start_time = Time.now
    end_time = start_time + duration

    # Create thread pool for concurrent requests
    pool = Concurrent::FixedThreadPool.new(concurrent_users)

    # Submit requests until time expires
    while Time.now < end_time
      pool.post { make_request }
      sleep(0.1) # Small delay to prevent overwhelming
    end

    # Wait for all requests to complete
    pool.shutdown
    pool.wait_for_termination(30)

    # Calculate and display results
    calculate_results(start_time)
    display_results

    @results
  end

  private

  def warmup_requests(count)
    count.times do |i|
      endpoint = select_endpoint
      make_request(endpoint)
      print "\r🔥 Warmup: #{i + 1}/#{count}" if (i + 1) % 5 == 0
    end
    puts "\n✅ Warmup completed"
  end

  def make_request(endpoint = nil)
    endpoint ||= select_endpoint

    start_time = Time.now

    begin
      response = case endpoint[:method]
      when :get
                   self.class.get(endpoint[:path])
      when :post
                   self.class.post(endpoint[:path])
      end

      response_time = (Time.now - start_time) * 1000 # Convert to milliseconds

      @mutex.synchronize do
        @results[:requests] += 1
        @results[:response_times] << response_time
        @results[:total_time] += response_time
      end

      # Log slow requests
      if response_time > 1000 # > 1 second
        puts "\n⚠️  Slow request: #{endpoint[:path]} took #{response_time.round(2)}ms"
      end

    rescue => e
      @mutex.synchronize do
        @results[:errors] += 1
        @results[:error_details] << {
          endpoint: endpoint[:path],
          error: e.message,
          timestamp: Time.now
        }
      end
      puts "\n❌ Error on #{endpoint[:path]}: #{e.message}"
    end
  end

  def select_endpoint
    # Weighted random selection based on realistic traffic patterns
    total_weight = ENDPOINTS.sum { |e| e[:weight] }
    random = rand(total_weight)

    current_weight = 0
    ENDPOINTS.each do |endpoint|
      current_weight += endpoint[:weight]
      return endpoint if random < current_weight
    end

    ENDPOINTS.first
  end

  def calculate_results(start_time)
    @results[:duration] = Time.now - start_time
    @results[:requests_per_second] = @results[:requests] / @results[:duration]
    @results[:error_rate] = (@results[:errors].to_f / @results[:requests] * 100).round(2)

    if @results[:response_times].any?
      sorted_times = @results[:response_times].sort
      @results[:avg_response_time] = (@results[:total_time] / @results[:requests]).round(2)
      @results[:p50_response_time] = percentile(sorted_times, 50)
      @results[:p90_response_time] = percentile(sorted_times, 90)
      @results[:p95_response_time] = percentile(sorted_times, 95)
      @results[:p99_response_time] = percentile(sorted_times, 99)
      @results[:max_response_time] = sorted_times.max
    end
  end

  def percentile(sorted_array, percentile)
    index = (percentile / 100.0) * (sorted_array.length - 1)
    lower = sorted_array[index.floor]
    upper = sorted_array[index.ceil]
    lower + (upper - lower) * (index - index.floor)
  end

  def display_results
    puts "\n📈 Load Test Results"
    puts "=" * 50
    puts "Total Requests: #{@results[:requests]}"
    puts "Total Errors: #{@results[:errors]}"
    puts "Error Rate: #{@results[:error_rate]}%"
    puts "Duration: #{@results[:duration].round(2)} seconds"
    puts "Requests/Second: #{@results[:requests_per_second].round(2)}"
    puts ""
    puts "Response Times (ms):"
    puts "  Average: #{@results[:avg_response_time]}"
    puts "  P50 (Median): #{@results[:p50_response_time]&.round(2)}"
    puts "  P90: #{@results[:p90_response_time]&.round(2)}"
    puts "  P95: #{@results[:p95_response_time]&.round(2)}"
    puts "  P99: #{@results[:p99_response_time]&.round(2)}"
    puts "  Max: #{@results[:max_response_time]&.round(2)}"

    if @results[:error_details].any?
      puts "\n❌ Errors:"
      @results[:error_details].each do |error|
        puts "  #{error[:endpoint]}: #{error[:error]}"
      end
    end

    puts "\n🎯 Performance Assessment:"
    assess_performance
  end

  def assess_performance
    rps = @results[:requests_per_second]
    avg_latency = @results[:avg_response_time]
    p95_latency = @results[:p95_response_time]
    error_rate = @results[:error_rate]

    puts "  Throughput: #{rps.round(2)} req/s"

    if avg_latency && avg_latency < 200
      puts "  ✅ Average latency: #{avg_latency}ms (Excellent)"
    elsif avg_latency && avg_latency < 500
      puts "  ✅ Average latency: #{avg_latency}ms (Good)"
    elsif avg_latency && avg_latency < 1000
      puts "  ⚠️  Average latency: #{avg_latency}ms (Acceptable)"
    else
      puts "  ❌ Average latency: #{avg_latency}ms (Poor)"
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

    if error_rate < 1
      puts "  ✅ Error rate: #{error_rate}% (Excellent)"
    elsif error_rate < 5
      puts "  ⚠️  Error rate: #{error_rate}% (Acceptable)"
    else
      puts "  ❌ Error rate: #{error_rate}% (Poor)"
    end
  end
end

# Run the load test
if __FILE__ == $0
  puts "Vantura Load Testing Tool"
  puts "Make sure your Rails server is running on localhost:3001"
  puts "Press Enter to start load test..."
  gets

  tester = VanturaLoadTester.new

  # Test configurations
  puts "\nChoose test configuration:"
  puts "1. Light load (5 users, 30 seconds)"
  puts "2. Medium load (10 users, 60 seconds)"
  puts "3. Heavy load (20 users, 120 seconds)"
  puts "4. Custom"

  choice = gets.chomp

  case choice
  when "1"
    tester.run_load_test(duration: 30, concurrent_users: 5, warmup: 5)
  when "2"
    tester.run_load_test(duration: 60, concurrent_users: 10, warmup: 10)
  when "3"
    tester.run_load_test(duration: 120, concurrent_users: 20, warmup: 15)
  when "4"
    print "Duration (seconds): "
    duration = gets.chomp.to_i
    print "Concurrent users: "
    users = gets.chomp.to_i
    print "Warmup requests: "
    warmup = gets.chomp.to_i
    tester.run_load_test(duration: duration, concurrent_users: users, warmup: warmup)
  else
    puts "Invalid choice, running medium load test..."
    tester.run_load_test(duration: 60, concurrent_users: 10, warmup: 10)
  end
end
