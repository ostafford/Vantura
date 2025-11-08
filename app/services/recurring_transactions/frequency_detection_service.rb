module RecurringTransactions
  class FrequencyDetectionService < ApplicationService
    def initialize(account, transaction)
      @account = account
      @transaction = transaction
    end

    def call
      # Find similar transactions (same merchant pattern, similar amount)
      similar_transactions = find_similar_transactions

      return { frequency: nil, confidence: 0 } if similar_transactions.count < 2

      # Analyze date patterns
      frequencies = analyze_frequencies(similar_transactions)

      # Return most likely frequency with confidence score
      best_match = frequencies.max_by { |_freq, count| count }
      return { frequency: nil, confidence: 0 } unless best_match

      frequency, count = best_match
      confidence = calculate_confidence(count, similar_transactions.count)

      { frequency: frequency, confidence: confidence }
    end

    private

    def find_similar_transactions
      merchant_pattern = RecurringTransaction.extract_merchant_pattern(@transaction.description)
      return [] if merchant_pattern.blank?

      # Find transactions with similar merchant pattern and amount
      @account.transactions
              .real
              .where("description LIKE ?", "%#{merchant_pattern}%")
              .where("ABS(amount - ?) <= ?", @transaction.amount, @transaction.amount.abs * 0.1) # Within 10% of amount
              .order(transaction_date: :desc)
              .limit(20)
    end

    def analyze_frequencies(transactions)
      return {} if transactions.count < 2

      # Sort by date
      sorted = transactions.sort_by(&:transaction_date)
      frequencies = Hash.new(0)

      # Calculate intervals between consecutive transactions
      (1...sorted.length).each do |i|
        interval_days = (sorted[i].transaction_date - sorted[i - 1].transaction_date).to_i
        frequency = detect_frequency_from_interval(interval_days)
        frequencies[frequency] += 1 if frequency
      end

      frequencies
    end

    def detect_frequency_from_interval(interval_days)
      case interval_days
      when 6..8
        "weekly"
      when 13..15
        "fortnightly"
      when 28..31
        "monthly"
      when 88..93
        "quarterly"
      when 360..370
        "yearly"
      else
        nil
      end
    end

    def calculate_confidence(match_count, total_count)
      # Confidence is based on how many intervals match the same frequency
      # More matches = higher confidence
      base_confidence = (match_count.to_f / total_count) * 100

      # Boost confidence if we have many matches
      if match_count >= 3
        base_confidence += 20
      elsif match_count >= 2
        base_confidence += 10
      end

      [ base_confidence, 100 ].min.round
    end
  end
end
