module Availability
  module Model

    def availability_in(inventory_pool, exclude_reservations: [], sanitize_invalid_entitled_quantity: false, time_window: nil)
      Availability::Main.new(model: self,
                             inventory_pool: inventory_pool,
                             exclude_reservations: exclude_reservations,
                             sanitize_invalid_entitled_quantity: sanitize_invalid_entitled_quantity,
                             time_window: time_window)
    end

    # One availability per part of the period from start_date to end_date
    # (see Availability::Main.intervals), by the hour with a time_window
    # [start_time of start_date, end_time of end_date]. A quantity is
    # available when it is available in all of them.
    def availabilities_in(inventory_pool, start_date:, end_date:, time_window: nil, exclude_reservations: [])
      running = inventory_pool
                .running_reservations
                .where(model_id: id)
                .where.not(id: exclude_reservations.presence || [])
      period = Availability::Main.period(start_date, end_date, time_window)
      Availability::Main
        .reservations_per_interval(running, period)
        .map do |reservations|
          Availability::Main.new(model: self,
                                 inventory_pool: inventory_pool,
                                 exclude_reservations: exclude_reservations,
                                 reservations: reservations)
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
