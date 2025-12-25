module UpApi
  # Base error class for all Up API errors
  class ApiError < StandardError
    attr_reader :status_code, :response_body

    def initialize(message, status_code = nil, response_body = nil)
      super(message)
      @status_code = status_code
      @response_body = response_body
    end
  end

  # Raised when authentication fails (401)
  class AuthenticationError < ApiError
    def initialize(message = "Invalid or expired token", status_code = 401, response_body = nil)
      super(message, status_code, response_body)
    end
  end

  # Raised when rate limit is exceeded (429)
  class RateLimitError < ApiError
    attr_reader :retry_after

    def initialize(message = "Rate limit exceeded", status_code = 429, response_body = nil, retry_after: nil)
      super(message, status_code, response_body)
      @retry_after = retry_after || 60
    end
  end

  # Raised when resource is not found (404)
  class NotFoundError < ApiError
    def initialize(message = "Resource not found", status_code = 404, response_body = nil)
      super(message, status_code, response_body)
    end
  end

  # Raised when server error occurs (5xx)
  class ServerError < ApiError
    def initialize(message = "Server error", status_code = nil, response_body = nil)
      super(message, status_code, response_body)
    end
  end
end

