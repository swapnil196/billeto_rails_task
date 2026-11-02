# frozen_string_literal: true

class CreateEventVoters < ActiveRecord::Migration[7.2]
  def change
    create_table :event_voters do |t|
      t.string :event_tid, null: false
      t.string :user_id, null: false

      # The vote this person currently holds. NULL means they have none: they
      # withdrew it. The row survives either way, because "used to like this"
      # is the thing the listing wants to show and current state cannot say.
      t.string :direction

      t.boolean :ever_upvoted, null: false, default: false

      t.timestamps
    end

    add_index :event_voters, [ :event_tid, :user_id ], unique: true
    add_index :event_voters, :event_tid
  end
end
