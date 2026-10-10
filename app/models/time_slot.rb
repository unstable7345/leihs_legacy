# A time slot an inventory pool offers for same-day reservations (managed in
# admin). Reservations of a time slot copy its start_time/end_time.
class TimeSlot < ApplicationRecord
  belongs_to :inventory_pool

  # Times of day as "HH:MM:SS" strings, like Reservation#start_time.
  attribute :start_time, :string
  attribute :end_time, :string

  default_scope { order(:position, :start_time, :name) }

  def as_json(_options = {})
    { name: name, start_time: start_time, end_time: end_time }
  end
end
