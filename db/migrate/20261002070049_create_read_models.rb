class CreateReadModels < ActiveRecord::Migration[7.2]
  def change
    create_table :event_vote_tallies do |t|
      t.string :event_tid, null: false
      t.integer :ups, null: false, default: 0
      t.integer :downs, null: false, default: 0

      t.timestamps
    end

    add_index :event_vote_tallies, :event_tid, unique: true

    create_table :processed_facts do |t|
      t.string :handler, null: false
      t.string :event_id, null: false

      t.datetime :created_at, null: false
    end

    add_index :processed_facts, [ :handler, :event_id ], unique: true
  end
end
