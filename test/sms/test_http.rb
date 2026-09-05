# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    module HTTP
      class TestHttp < Minitest::Test
        ResponseStub = Struct.new(:status, :headers, :body)

        class FakeResponse
          attr_reader :code, :body

          def initialize(code, headers, body)
            @code = code
            @headers = headers
            @body = body
          end

          def each_header(&)
            return enum_for(__method__) unless block_given?

            @headers.each(&)
          end
        end

        class FakeHttp
          attr_accessor :use_ssl, :open_timeout, :read_timeout, :write_timeout
          attr_reader :last_request

          def initialize(response)
            @response = response
          end

          def start
            yield self
          end

          def request(request)
            @last_request = request
            @response
          end
        end

        class FakeHttpWithoutWriteTimeout < FakeHttp
          undef_method :write_timeout=
        end

        def test_normalizes_response_and_status
          response = Response.new(status: 202, headers: { "X-Request-ID" => "abc" }, body: "accepted")

          assert_equal 202, response.status
          assert_equal({ "X-Request-ID" => "abc" }, response.headers)
          assert_equal "accepted", response.body
          assert_predicate response, :successful?
          refute_predicate Response.new(status: 500), :successful?
        end

        def test_rejects_invalid_response_values
          assert_raises(ArgumentError) { Response.new(status: "200") }
          assert_raises(ArgumentError) { Response.new(status: 200, headers: []) }
        end

        def test_client_serializes_requests_and_normalizes_transport_response
          calls = []
          transport = lambda do |**options|
            calls << options
            Response.new(status: 201, body: "created")
          end
          client = Client.new(transport: transport, open_timeout: 1, read_timeout: 2, write_timeout: 3)

          response = client.request(
            :post,
            "https://example.test/messages",
            headers: { "X-Trace" => 123 },
            body: { to: "+1", body: "hello" }
          )

          assert_equal 201, response.status
          assert_equal :post, calls.first[:method]
          assert_equal({ "X-Trace" => "123", "Content-Type" => "application/json" }, calls.first[:headers])
          assert_equal({ "to" => "+1", "body" => "hello" }, JSON.parse(calls.first[:body]))
          assert_equal 1, calls.first[:open_timeout]
          assert_equal 2, calls.first[:read_timeout]
          assert_equal 3, calls.first[:write_timeout]
        end

        def test_client_accepts_string_and_nil_bodies
          bodies = []
          client = Client.new(
            transport: lambda do |**options|
              bodies << options[:body]
              Response.new(status: 204)
            end
          )

          client.request(:get, "https://example.test/messages")
          client.request(:post, "https://example.test/messages", body: "raw")

          assert_equal [nil, "raw"], bodies
        end

        def test_client_validates_headers_and_body
          client = Client.new(transport: ->(**) { Response.new(status: 200) })

          assert_raises(ArgumentError) { client.request(:get, "https://example.test", headers: []) }
          assert_raises(ArgumentError) { client.request(:post, "https://example.test", body: []) }
        end

        def test_client_normalizes_struct_like_and_rejects_invalid_transport_responses
          response = ResponseStub.new(200, { "Content-Type" => "text/plain" }, "ok")
          client = Client.new(transport: ->(**) { response })

          assert_equal "ok", client.request(:get, "https://example.test").body

          invalid_client = Client.new(transport: ->(**) { Object.new })
          assert_raises(ArgumentError) { invalid_client.request(:get, "https://example.test") }
        end

        def test_client_maps_timeout_and_network_failures
          timeout_client = Client.new(transport: ->(**) { raise ::Timeout::Error, "slow" })
          network_client = Client.new(transport: ->(**) { raise SocketError, "offline" })

          assert_raises(Errors::Timeout) { timeout_client.request(:get, "https://example.test") }
          assert_raises(Errors::Network) { network_client.request(:get, "https://example.test") }
        end

        def test_client_enforces_total_timeout
          client = Client.new(total_timeout: 1, transport: ->(**) { raise ::Timeout::Error, "slow" })

          assert_raises(Errors::Timeout) { client.request(:get, "https://example.test") }
        end

        def test_redacts_sensitive_headers
          client = Client.new
          headers = client.redacted_headers(
            "Authorization" => "secret",
            "X-Api-Key" => "key",
            "X-Token" => "token",
            "Accept" => "application/json"
          )

          assert_equal "[REDACTED]", headers["Authorization"]
          assert_equal "[REDACTED]", headers["X-Api-Key"]
          assert_equal "[REDACTED]", headers["X-Token"]
          assert_equal "application/json", headers["Accept"]
          assert_predicate headers, :frozen?
        end

        def test_net_http_transport_configures_and_executes_request
          response = FakeResponse.new("202", { "x-request-id" => "abc" }, "accepted")
          http = FakeHttp.new(response)
          transport = NetHttpTransport.new(http_factory: ->(_uri) { http })

          normalized = transport.call(
            method: :post,
            url: "https://example.test/messages?async=true",
            headers: { "Content-Type" => "application/json" },
            body: "{}",
            open_timeout: 1,
            read_timeout: 2,
            write_timeout: 3
          )

          assert_equal 202, normalized.status
          headers = []
          response.each_header { |header, value| headers << [header, value] }

          assert http.use_ssl
          assert_equal [%w[x-request-id abc]], headers
          assert_equal 1, http.open_timeout
          assert_equal 2, http.read_timeout
          assert_equal 3, http.write_timeout
          assert_equal "POST", http.last_request.method
          assert_equal "/messages?async=true", http.last_request.path
          assert_equal "{}", http.last_request.body
        end

        def test_net_http_transport_supports_plain_http_and_empty_body
          response = FakeResponse.new("204", {}, nil)
          http = FakeHttpWithoutWriteTimeout.new(response)
          transport = NetHttpTransport.new(http_factory: ->(_uri) { http })

          normalized = transport.call(
            method: "get",
            url: "http://example.test/messages",
            headers: {},
            body: nil,
            open_timeout: 1,
            read_timeout: 2,
            write_timeout: 3
          )

          assert_equal 204, normalized.status
          refute http.use_ssl
          assert_nil http.last_request.body
        end
      end
    end
  end
end
