class AddGiftReceiptFooterToStores < ActiveRecord::Migration[8.1]
  def change
    add_column :stores, :gift_receipt_footer, :text
  end
end
