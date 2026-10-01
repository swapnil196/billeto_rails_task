class CreateEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :events do |t|
      t.string :tid, null: false

      t.string :external_id, null: false

      t.string :title, null: false
      t.text :description
      t.string :image_url
      t.string :event_url
      t.datetime :starts_at, null: false
      t.datetime :ends_at

      t.string :state
      t.string :kind
      t.boolean :available
      t.string :organiser_name
      t.string :venue_name
      t.string :category
      t.integer :minimum_price_cents
      t.string :currency

      t.string :payload_digest

      t.timestamps
    end

    add_index :events, :tid, unique: true
    add_index :events, :external_id, unique: true
    add_index :events, :starts_at
  end
end
