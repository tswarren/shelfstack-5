# frozen_string_literal: true

# OD-P8-10 revision: publication_date is an optional exact calendar date.
# Partial-date precision (year/month placeholders) is removed.
class SimplifyProductPublicationDate < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :products, name: "products_publication_date_both_or_neither"
    remove_check_constraint :products, name: "products_publication_date_precision_allowed"
    remove_column :products, :publication_date_precision, :string, limit: 8
  end
end
