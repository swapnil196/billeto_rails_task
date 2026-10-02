class CreateVotes < ActiveRecord::Migration[7.2]
  def change
    create_table :votes do |t|
      t.string :event_tid, null: false
      t.string :user_id, null: false
      t.string :direction, null: false

      t.timestamps
    end

    add_index :votes, [ :event_tid, :user_id ], unique: true
    add_index :votes, :user_id
  end
end
