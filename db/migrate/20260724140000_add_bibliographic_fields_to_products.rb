# frozen_string_literal: true

# Gate 8b Slice 1 (OD-P8-10): accepted minimum bibliographic Product fields.
# `publication_date` always stores a complete Y-M-D value; `publication_date_precision`
# records how much of that date the source actually asserted
# (year -> YYYY-01-01, month -> YYYY-MM-01, day -> exact date). See
# Catalog::PartialPublicationDate for the full contract.
class AddBibliographicFieldsToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :publication_date, :date
    add_column :products, :publication_date_precision, :string, limit: 8
    add_column :products, :language_code, :string, limit: 16
    add_column :products, :edition_statement, :string

    add_check_constraint :products,
                         "publication_date_precision IS NULL OR publication_date_precision IN ('year', 'month', 'day')",
                         name: "products_publication_date_precision_allowed"
    add_check_constraint :products,
                         "(publication_date IS NULL) = (publication_date_precision IS NULL)",
                         name: "products_publication_date_both_or_neither"
  end
end
