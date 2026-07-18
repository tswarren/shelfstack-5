# frozen_string_literal: true

# Base for application services. Prefer `SomeService.call(...)` over
# constructor + `#call` at call sites. Subclasses implement `#call`.
class ApplicationService
  def self.call(...)
    new(...).call
  end
end
