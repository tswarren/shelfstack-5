# frozen_string_literal: true

require "net/http"
require "uri"

module Catalog
  module Providers
    # Real HTTPS transport. HTTPS-only, explicit connect/read timeouts, and a
    # bounded response body -- and exactly one attempt (no retry; see
    # Catalog::Providers::HttpTransport for why retry is layered above this).
    class NetHttpTransport < HttpTransport
      OPEN_TIMEOUT = 5
      READ_TIMEOUT = 10
      MAX_BODY_BYTES = 2 * 1024 * 1024

      def get(url:, headers: {})
        uri = URI.parse(url)
        raise ArgumentError, "transport requires an HTTPS URL" unless uri.is_a?(URI::HTTPS)

        perform(uri, headers)
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise TimeoutError, "timed out contacting #{uri&.host}"
      rescue SocketError, Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, EOFError, IOError => e
        raise ConnectionError, "connection error contacting #{uri&.host} (#{e.class})"
      end

      private

      def perform(uri, headers)
        request = Net::HTTP::Get.new(uri)
        headers.each { |key, value| request[key.to_s] = value }

        status = nil
        response_headers = {}
        body = +""

        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.request(request) do |response|
            status = response.code.to_i
            response.each_header { |key, value| response_headers[key] = value }
            response.read_body do |chunk|
              body << chunk
              if body.bytesize > MAX_BODY_BYTES
                raise ResponseTooLargeError, "response from #{uri.host} exceeded the maximum allowed size"
              end
            end
          end
        end

        Response.new(status: status, body: body, headers: response_headers)
      end
    end
  end
end
