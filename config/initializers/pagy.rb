# frozen_string_literal: true

# Pagy 43+ configuration.
# See https://ddnexus.github.io/pagy/toolbox/configuration/initializer/
#
# Requested page size is clamped in ApplicationController#pagy_limit
# (default 25, maximum 100). Out-of-range pages raise Pagy::RangeError,
# which ApplicationController rescues by redirecting to the last page.
Pagy::OPTIONS[:limit] = 25
Pagy::OPTIONS[:raise_range_error] = true
Pagy::OPTIONS.freeze
