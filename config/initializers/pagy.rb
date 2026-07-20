# frozen_string_literal: true

# Pagination defaults for back-office index screens.
# Requested page size is clamped in ApplicationController#pagy_limit
# (default 25, maximum 100). Out-of-range pages raise Pagy::OverflowError,
# which ApplicationController rescues by redirecting to the last page.
Pagy::DEFAULT[:limit] = 25
