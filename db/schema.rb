# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_10_02_070049) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "event_store_events", force: :cascade do |t|
    t.uuid "event_id", null: false
    t.string "event_type", null: false
    t.jsonb "metadata"
    t.jsonb "data", null: false
    t.datetime "created_at", null: false
    t.datetime "valid_at"
    t.index "COALESCE(valid_at, created_at)", name: "index_event_store_events_on_as_of"
    t.index ["created_at"], name: "index_event_store_events_on_created_at"
    t.index ["event_id"], name: "index_event_store_events_on_event_id", unique: true
    t.index ["event_type"], name: "index_event_store_events_on_event_type"
    t.index ["valid_at"], name: "index_event_store_events_on_valid_at"
  end

  create_table "event_store_events_in_streams", force: :cascade do |t|
    t.string "stream", null: false
    t.integer "position"
    t.uuid "event_id", null: false
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_event_store_events_in_streams_on_created_at"
    t.index ["event_id"], name: "index_event_store_events_in_streams_on_event_id"
    t.index ["stream", "event_id"], name: "index_event_store_events_in_streams_on_stream_and_event_id", unique: true
    t.index ["stream", "position"], name: "index_event_store_events_in_streams_on_stream_and_position", unique: true
  end

  create_table "event_vote_tallies", force: :cascade do |t|
    t.string "event_tid", null: false
    t.integer "ups", default: 0, null: false
    t.integer "downs", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_tid"], name: "index_event_vote_tallies_on_event_tid", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.string "tid", null: false
    t.string "external_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "image_url"
    t.string "event_url"
    t.datetime "starts_at", null: false
    t.datetime "ends_at"
    t.string "state"
    t.string "kind"
    t.boolean "available"
    t.string "organiser_name"
    t.string "venue_name"
    t.string "category"
    t.integer "minimum_price_cents"
    t.string "currency"
    t.string "payload_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_events_on_external_id", unique: true
    t.index ["starts_at"], name: "index_events_on_starts_at"
    t.index ["tid"], name: "index_events_on_tid", unique: true
  end

  create_table "processed_facts", force: :cascade do |t|
    t.string "handler", null: false
    t.string "event_id", null: false
    t.datetime "created_at", null: false
    t.index ["handler", "event_id"], name: "index_processed_facts_on_handler_and_event_id", unique: true
  end

  create_table "votes", force: :cascade do |t|
    t.string "event_tid", null: false
    t.string "user_id", null: false
    t.string "direction", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_tid", "user_id"], name: "index_votes_on_event_tid_and_user_id", unique: true
    t.index ["user_id"], name: "index_votes_on_user_id"
  end

  add_foreign_key "event_store_events_in_streams", "event_store_events", column: "event_id", primary_key: "event_id"
end
