class Manage::AvailabilityController < Manage::ApplicationController

  before_action :before_action_hook

  def before_action_hook
    @models = Model.where id: params[:model_ids]
    head :bad_request and return if @models.blank?
    @availabilities = []
  end

  def index
    user = User.find params[:user_id]
    @models.each do |model|
      @availabilities.push \
        id: "#{model.id}-#{user.id}-#{current_inventory_pool.id}",
        changes: \
          model
            .availability_in(current_inventory_pool)
            .available_total_quantities,
        # availability per time window booked by the reservations and the
        # requested one, keyed by "start_time-end_time"
        changes_by_window: changes_by_window(model, requested_time_window),
        # exactly for each reservation by the hour over several days
        changes_by_period: changes_by_period(model),
        total_rentable: \
          model
            .items
            .where(inventory_pool_id: current_inventory_pool)
            .unretired
            .borrowable
            .count,
        inventory_pool_id: current_inventory_pool.id,
        model_id: model.id
    end
  end

  def in_stock
    @models.each do |model|
      entitled_in_groups = \
        Entitlement
        .joins(:entitlement_group)
        .where(
          entitlement_groups: { inventory_pool_id: current_inventory_pool.id }
        )
        .where(model_id: model.id)
        .map(&:quantity)
        .reduce(&:+)
      entitled_in_groups ||= 0

      @availabilities.push \
        id: "#{model.id}-#{current_inventory_pool.id}",
        total_rentable: \
          model
            .items
            .where(inventory_pool_id: current_inventory_pool)
            .borrowable
            .unretired
            .count,
        in_stock: \
          model
            .items
            .where(inventory_pool_id: current_inventory_pool)
            .borrowable
            .unretired
            .in_stock
            .count,
        entitled_in_groups: entitled_in_groups,
        inventory_pool_id: current_inventory_pool.id,
        model_id: model.id
    end
    render :index
  end

  private

  # The [start_time, end_time] ("HH:MM:SS") of the params, e.g. the time slot
  # chosen when adding or changing reservations; nil without one.
  def requested_time_window
    window = [params[:start_time], params[:end_time]]
    window if window.all? { |t| t.to_s.match?(/\A\d{2}:\d{2}:\d{2}\z/) }
  end

  # The availability of each period of the reservations by the hour over
  # several days (which windows on each day can not tell, e.g. from 16:00 to
  # 10:00 the next day), keyed by "YYYY-MM-DD HH:MM:SS/YYYY-MM-DD HH:MM:SS":
  # one per part of the period (see Availability::Main.intervals).
  def changes_by_period(model)
    current_inventory_pool
      .running_reservations
      .where(model_id: model.id)
      .where.not(start_time: nil)
      .where('reservations.start_date < reservations.end_date')
      .reorder(nil)
      .distinct
      .pluck(:start_date, :end_date, :start_time, :end_time)
      .to_h do |start_date, end_date, start_time, end_time|
        window = [start_time, end_time].map { |t| t.to_s.first(8) }
        [Availability::Main.period(start_date, end_date, window).join('/'),
         model
           .availabilities_in(current_inventory_pool,
                              start_date: start_date,
                              end_date: end_date,
                              time_window: window)
           .map(&:available_total_quantities)]
      end
  end

  def changes_by_window(model, requested_window = nil)
    running = current_inventory_pool.running_reservations.where(model_id: model.id)
    windows = Availability::Main.time_windows_to_check(running, nil).compact
    windows |= [requested_window] if requested_window
    windows.to_h do |window|
      [window.join('-'),
       model
         .availability_in(current_inventory_pool, time_window: window)
         .available_total_quantities]
    end
  end

end
