# frozen_string_literal: true

# Canonical reference data only.
# Installation bootstrap (org/store/admin user) is explicit:
#   bin/rails shelfstack:bootstrap

load Rails.root.join("db/seeds/phase1_permissions.rb")
