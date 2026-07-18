# frozen_string_literal: true

namespace :shelfstack do
  desc "Bootstrap installation org, store, administrator role/user/membership (safe for re-runs)"
  task bootstrap: :environment do
    load Rails.root.join("db/seeds/bootstrap.rb")
  end

  desc "Seed organization-owned reference data (sequences + classification/catalog CSV masters)"
  task seed_reference_data: :environment do
    load Rails.root.join("db/seeds/reference_data.rb")
  end

  desc "Grant every catalog permission to the administrator role (audited; additive)"
  task sync_admin_permissions: :environment do
    organization = Organization.first
    raise "No organization found; run bin/rails shelfstack:bootstrap first" unless organization

    role = organization.roles.find_by(code: "administrator")
    raise "No administrator role found for organization #{organization.code}" unless role

    actor_username = ENV.fetch("SHELFSTACK_BOOTSTRAP_USERNAME") do
      raise "SHELFSTACK_BOOTSTRAP_USERNAME is required to identify the audit actor" unless Rails.env.development? || Rails.env.test?

      "admin"
    end
    actor = User.find_by(username: actor_username.to_s.strip.downcase)
    raise "Audit actor user #{actor_username.inspect} not found" unless actor

    store = actor.default_store || organization.stores.order(:code).first
    raise "No store available for audit context" unless store

    Administration::SyncAdministratorPermissions.call(
      role: role,
      actor: actor,
      organization: organization,
      store: store
    )

    puts "Synchronized administrator permissions for organization=#{organization.code}"
  end
end
