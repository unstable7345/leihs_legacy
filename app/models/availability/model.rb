module Availability
  module Model

    def availability_in(inventory_pool, exclude_reservations: [], sanitize_invalid_entitled_quantity: false, time_window: nil)
      Availability::Main.new(model: self,
                             inventory_pool: inventory_pool,
                             exclude_reservations: exclude_reservations,
                             sanitize_invalid_entitled_quantity: sanitize_invalid_entitled_quantity,
                             time_window: time_window)
    end

    # One availability per time window to check (see
    # Availability::Main.time_windows_to_check). A quantity is available when
    # it is available in all of them.
    def availabilities_in(inventory_pool, time_window: nil, exclude_reservations: [])
      running = inventory_pool
                .running_reservations
                .where(model_id: id)
                .where.not(id: exclude_reservations.presence || [])
      Availability::Main.time_windows_to_check(running, time_window).map do |window|
        Availability::Main.new(model: self,
                               inventory_pool: inventory_pool,
                               exclude_reservations: exclude_reservations,
                               time_window: window)
      end
    end

    def being_maintained_until(pool, date = Time.zone.today)
      maintenance_period.to_i.times do
        date = pool.next_open_date(date + 1.day)
      end

      date
    end

  end
end
