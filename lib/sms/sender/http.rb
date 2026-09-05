# frozen_string_literal: true

require "json"
require "net/http"
require "timeout"
require "uri"

module Sms
  module Sender
    # Internal HTTP transport used by provider adapters.
    module HTTP
      # Normalized HTTP response returned by the transport.
      class Response
        attr_reader :status, :headers, :body

        # @param status [Integer] HTTP status code
        # @param headers [Hash] response headers
        # @param body [String] response body
        def initialize(status:, headers: {}, body: "")
          raise ArgumentError, "status must be an Integer" unless status.is_a?(Integer)
          raise ArgumentError, "headers must be a Hash" unless headers.is_a?(Hash)

          @status = status
          @headers = headers.transform_keys(&:to_s).freeze
          @body = body.to_s.freeze
          freeze
        end

        # @return [Boolean] whether the response has a 2xx status
        def successful?
          status.between?(200, 299)
        end
      end

      # Standard-library Net::HTTP implementation of the transport boundary.
      class NetHttpTransport
        # @param http_factory [#call] factory returning a configured HTTP client
        def initialize(http_factory: ->(uri) { Net::HTTP.new(uri.host, uri.port) })
          @http_factory = http_factory
        end

        # @return [Response] normalized HTTP response
        def call(method:, url:, headers:, body:, open_timeout:, read_timeout:, write_timeout:)
          uri = URI.parse(url)
          http = @http_factory.call(uri)
          http.use_ssl = true if uri.scheme == "https"
          http.open_timeout = open_timeout
          http.read_timeout = read_timeout
          http.write_timeout = write_timeout if http.respond_to?(:write_timeout=)

          request = Net::HTTPGenericRequest.new(
            method.to_s.upcase,
            !body.nil?,
            true,
            uri.request_uri,
            headers
          )
          request.body = body if body
          response = http.start { http.request(request) }
          Response.new(status: response.code.to_i, headers: response.each_header.to_h, body: response.body)
        end
      end

      # Executes HTTP requests and maps transport details into domain values.
      class Client
        # Default connection timeout in seconds.
        DEFAULT_OPEN_TIMEOUT = 5
        # Default response read timeout in seconds.
        DEFAULT_READ_TIMEOUT = 10
        # Default request write timeout in seconds.
        DEFAULT_WRITE_TIMEOUT = 10

        # @param transport [#call, nil] injectable transport implementation
        # @param open_timeout [Numeric] connection timeout in seconds
        # @param read_timeout [Numeric] response read timeout in seconds
        # @param write_timeout [Numeric] request write timeout in seconds
        # @param total_timeout [Numeric, nil] complete request timeout in seconds
        def initialize(transport: nil, open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT,
                       write_timeout: DEFAULT_WRITE_TIMEOUT, total_timeout: nil)
          @transport = transport || NetHttpTransport.new
          @open_timeout = open_timeout
          @read_timeout = read_timeout
          @write_timeout = write_timeout
          @total_timeout = total_timeout
        end

        # @param method [Symbol, String] HTTP method
        # @param url [String] absolute request URL
        # @param headers [Hash] request headers
        # @param body [String, Hash, nil] request body
        # @return [Response] normalized response
        def request(method, url, headers: {}, body: nil)
          request_headers = normalize_headers(headers)
          serialized_body, request_headers = serialize_body(body, request_headers)
          result = with_total_timeout do
            @transport.call(
              method: method,
              url: url,
              headers: request_headers,
              body: serialized_body,
              open_timeout: @open_timeout,
              read_timeout: @read_timeout,
              write_timeout: @write_timeout
            )
          end
          normalize_response(result)
        rescue ::Timeout::Error
          raise Errors::Timeout, "HTTP request timed out"
        rescue SocketError, SystemCallError, EOFError
          raise Errors::Network, "HTTP request failed"
        end

        # @param headers [Hash] request headers
        # @return [Hash] headers safe for diagnostics
        def redacted_headers(headers)
          redacted = normalize_headers(headers)
          redacted.each_key do |key|
            redacted[key] = "[REDACTED]" if sensitive_header?(key)
          end
          redacted.freeze
        end

        private

        def normalize_headers(headers)
          raise ArgumentError, "headers must be a Hash" unless headers.is_a?(Hash)

          headers.to_h { |key, value| [key.to_s, value.to_s] }
        end

        def serialize_body(body, headers)
          return [nil, headers] if body.nil?
          return [body, headers] if body.is_a?(String)
          return [JSON.generate(body), headers.merge("Content-Type" => "application/json")] if body.is_a?(Hash)

          raise ArgumentError, "body must be a String, Hash, or nil"
        end

        def with_total_timeout(&)
          return yield unless @total_timeout

          ::Timeout.timeout(@total_timeout, &)
        end

        def sensitive_header?(key)
          key = key.downcase
          key.include?("authorization") || key.include?("api-key") || key.include?("token")
        end

        def normalize_response(response)
          return response if response.is_a?(Response)

          unless response.respond_to?(:status) && response.respond_to?(:headers) && response.respond_to?(:body)
            raise ArgumentError, "transport must return an HTTP::Response"
          end

          Response.new(status: response.status, headers: response.headers, body: response.body)
        end
      end
    end
  end
end
