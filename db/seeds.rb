# frozen_string_literal: true

# Installation-global definitions only (permissions).
# Organization bootstrap: bin/rails shelfstack:bootstrap
# Org-owned masters: bin/rails shelfstack:seed_reference_data

load Rails.root.join("db/seeds/permissions.rb")
