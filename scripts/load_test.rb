#!/usr/bin/env ruby
# Simple Load Testing Script for Vantura
# Quick performance validation for Puma configuration

require 'httparty'
require 'concurrent'
require 'time'

class SimpleLoadTester
  include HTTParty
  base_uri 'http://localhost:3001'

  def initialize
    @results = []
    @errors = 0
  end

  def run_test(duration: 30, concurrent_users: 5)
    puts "🚀 Starting Simple Load Test"
    puts "Duration: #{duration} seconds, Users: #{concurrent_users}"
    puts "=" * 40

    start_time = Time.now
    end_time = start_time + duration

    # Create thread pool
    pool = Concurrent::FixedThreadPool.new(concurrent_users)

    # Submit requests
    while Time.now < end_time
      pool.post { make_request }
      sleep(0.2)
    end

    pool.shutdown
    pool.wait_for_termination(10)

    display_results(start_time)
  end

  private

  def make_request
    endpoints = [ '/up', '/', '/calendar', '/trends' ]
    endpoint = endpoints.sample

    start_time = Time.now

    begin
      response = self.class.get(endpoint)
      response_time = (Time.now - start_time) * 1000

      @results << {
        endpoint: endpoint,
        response_time: response_time,
        status: response.code
      }

    rescue => e
      @errors += 1
      puts "❌ Error: #{e.message}"
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
    end

    puts "\n📊 Results:"
    puts "Total Requests: #{total_requests}"
    puts "Errors: #{@errors}"
    puts "Duration: #{duration.round(2)}s"
    puts "Requests/sec: #{requests_per_second.round(2)}"

    if @results.any?
      puts "Avg Response Time: #{avg_response_time.round(2)}ms"
      puts "Min Response Time: #{min_response_time.round(2)}ms"
      puts "Max Response Time: #{max_response_time.round(2)}ms"
    end

    puts "\n🎯 Assessment:"
    if avg_response_time && avg_response_time < 200
      puts "✅ Performance: Excellent (< 200ms avg)"
    elsif avg_response_time && avg_response_time < 500
      puts "✅ Performance: Good (< 500ms avg)"
    else
      puts "⚠️  Performance: Needs optimization"
    end
  end
end

# Quick test function
def quick_test
  puts "Quick Vantura Load Test"
  puts "Make sure server is running on localhost:3001"
  puts "Starting in 3 seconds..."
  sleep(3)

  tester = SimpleLoadTester.new
  tester.run_test(duration: 30, concurrent_users: 5)
end

# Run if called directly
quick_test if __FILE__ == $0
