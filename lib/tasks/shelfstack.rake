# frozen_string_literal: true

namespace :shelfstack do
  desc "Bootstrap installation org, store, administrator role/user/membership (safe for re-runs)"
  task bootstrap: :environment do
    load Rails.root.join("db/seeds/bootstrap.rb")
  end
end
