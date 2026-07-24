# frozen_string_literal: true

# Deterministic test double for Catalog::Providers::HttpTransport (Gate 8b
# Slice 2). Never opens a real socket. Each #get call pops the next queued
# item: a Response, an exception instance/class (raised), or a callable
# (invoked with no args). Records every call so tests can assert on
# call_count / requested urls+headers (e.g. "zero transport calls" for an
# unsupported identifier, or "retry once for 503 then success").
class FakeHttpTransport < Catalog::Providers::HttpTransport
  Call = Data.define(:url, :headers)

  attr_reader :calls

  def initialize(responses: [])
    super()
    @responses = responses.dup
    @calls = []
  end

  def call_count
    @calls.size
  end

  def get(url:, headers: {})
    @calls << Call.new(url: url, headers: headers)

    step = @responses.shift
    raise "FakeHttpTransport ran out of stubbed responses" if step.nil?

    case step
    when Class
      raise step
    when Exception
      raise step
    when Proc
      step.call
    else
      step
    end
  end

  def self.json_response(status:, fixture: nil, body: nil, headers: {})
    resolved_body = body || file_fixture_body(fixture)
    Catalog::Providers::HttpTransport::Response.new(status: status, body: resolved_body, headers: headers)
  end

  def self.file_fixture_body(fixture)
    Rails.root.join("test/fixtures/files", fixture).read
  end
end
