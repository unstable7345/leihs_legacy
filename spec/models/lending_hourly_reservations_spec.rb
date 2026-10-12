require "rails_helper"

describe "reservations by the hour in lending" do
  before :example do
    @pool = FactoryBot.create(:inventory_pool)
    @pool.update_columns(hourly_reservations: true,
                         hourly_reservations_start_time: "08:00",
                         hourly_reservations_end_time: "20:00")
    @pool.reload
    @user = FactoryBot.create(:customer, inventory_pool: @pool)
    @manager = FactoryBot.create(:lending_manager, inventory_pool: @pool)
    @model = FactoryBot.create(:model)
    FactoryBot.create(:item, model: @model, owner: @pool)
    @day = @pool.next_open_date(Time.zone.today + 1.day)
  end

  def reserve(**attrs)
    FactoryBot.create(:item_line,
      {inventory_pool: @pool, user: @user, model: @model, status: :approved,
       start_date: @day, end_date: @day + 1.day}.merge(attrs))
  end

  # the controller as an action of the given params would see it
  def controller_with(params)
    controller = Manage::ReservationsController.new
    controller.params = ActionController::Parameters.new(params)
    pool = @pool
    controller.define_singleton_method(:current_inventory_pool) { pool }
    controller
  end

  it "offers the times of the hours of the pool in steps of 30 minutes" do
    options = @pool.hourly_time_options
    expect(options.first(3)).to eq ["08:00:00", "08:30:00", "09:00:00"]
    expect(options.last).to eq "20:00:00"
    expect(options.size).to eq 25
    @pool.update_columns(hourly_reservations: false)
    expect(@pool.reload.hourly_time_options).to eq []
  end

  describe "changing the time line" do
    it "keeps both dates of a reservation by the hour over several days" do
      line = reserve
      line.update_time_line(@day, @day + 1.day, @manager, ["16:00:00", "10:00:00"])
      line.reload
      expect([line.start_date, line.end_date]).to eq [@day, @day + 1.day]
      expect([line.start_time, line.end_time]).to eq ["16:00:00", "10:00:00"]
    end

    it "refuses a reservation by the hour ending before it starts" do
      line = reserve
      expect { line.update_time_line(@day, @day, @manager, ["16:00:00", "10:00:00"]) }
        .to raise_error(/end has to be after the start/)
    end

    it "makes a reservation by the hour a whole-day one" do
      line = reserve(end_date: @day, start_time: "08:00:00", end_time: "13:00:00")
      line.update_time_line(@day, @day + 1.day, @manager, [nil, nil])
      line.reload
      expect([line.start_time, line.end_time]).to eq [nil, nil]
      expect(line.end_date).to eq @day + 1.day
    end

    it "keeps the times when not given" do
      line = reserve(end_date: @day, start_time: "08:00:00", end_time: "13:00:00")
      line.update_time_line(@day, @day + 1.day, @manager)
      line.reload
      expect([line.start_time, line.end_time]).to eq ["08:00:00", "13:00:00"]
      expect(line.end_date).to eq @day + 1.day
    end
  end

  describe "the times of the params" do
    it "are times within the hours of the pool" do
      expect(controller_with(start_time: "16:00", end_time: "10:00:00").send(:time_window_param))
        .to eq ["16:00:00", "10:00:00"]
    end

    it "are the whole day when blank, unchanged when missing" do
      expect(controller_with(start_time: "", end_time: "").send(:time_window_param)).to eq [nil, nil]
      expect(controller_with({}).send(:time_window_param)).to eq :keep
    end

    it "are refused outside the hours, off the steps or without both" do
      ["07:00:00", "20:30:00", "09:15:00"].each do |t|
        expect { controller_with(start_time: t, end_time: "12:00:00").send(:time_window_param) }
          .to raise_error(/within the hours/)
      end
      expect { controller_with(start_time: "10:00:00", end_time: "").send(:time_window_param) }
        .to raise_error(/within the hours/)
    end

    it "are refused when the pool only offers whole days" do
      @pool.update_columns(hourly_reservations: false)
      @pool.reload
      expect { controller_with(start_time: "10:00:00", end_time: "12:00:00").send(:time_window_param) }
        .to raise_error(/does not offer reservations by the hour/)
    end
  end

  describe "the availability of a requested time window" do
    def availability_controller(params)
      controller = Manage::AvailabilityController.new
      controller.params = ActionController::Parameters.new(params)
      pool = @pool
      controller.define_singleton_method(:current_inventory_pool) { pool }
      controller
    end

    # the quantity available in total at the day of the windows' changes
    def available_on(changes, day)
      changes.select { |date, _| date <= day }.max_by(&:first).second
    end

    it "is computed for a window without reservations" do
      reserve(start_date: @day, end_date: @day, start_time: "08:00:00", end_time: "13:00:00")
      controller = availability_controller(start_time: "13:00:00", end_time: "18:00:00")
      window = controller.send(:requested_time_window)
      expect(window).to eq ["13:00:00", "18:00:00"]

      by_window = controller.send(:changes_by_window, @model, window)
      # the morning reservation doesn't take the item in the afternoon
      expect(available_on(by_window["13:00:00-18:00:00"], @day)).to eq 1
      expect(available_on(by_window["08:00:00-13:00:00"], @day)).to eq 0
    end

    it "counts reservations over night in the windows they overlap" do
      reserve(start_date: @day, end_date: @day + 1.day, start_time: "16:00:00", end_time: "10:00:00")
      controller = availability_controller(start_time: "17:00:00", end_time: "19:00:00")
      by_window = controller.send(:changes_by_window, @model, controller.send(:requested_time_window))
      expect(available_on(by_window["17:00:00-19:00:00"], @day)).to eq 0

      controller = availability_controller(start_time: "11:00:00", end_time: "15:00:00")
      by_window = controller.send(:changes_by_window, @model, controller.send(:requested_time_window))
      expect(available_on(by_window["11:00:00-15:00:00"], @day)).to eq 1
    end

    it "counts whole-day reservations" do
      reserve(start_date: @day, end_date: @day)
      controller = availability_controller(start_time: "13:00:00", end_time: "18:00:00")
      by_window = controller.send(:changes_by_window, @model, controller.send(:requested_time_window))
      expect(available_on(by_window["13:00:00-18:00:00"], @day)).to eq 0
    end

    it "ignores malformed times" do
      expect(availability_controller(start_time: "", end_time: "").send(:requested_time_window)).to be_nil
      expect(availability_controller(start_time: "13:00; DROP", end_time: "18:00:00")
               .send(:requested_time_window)).to be_nil
    end
  end

  it "creates a reservation by the hour over several days" do
    controller = controller_with({})
    controller.define_singleton_method(:group_manager?) { false }
    line = controller.send(:create_reservation,
      @user, nil, @pool, :approved, @model, 1,
      @day.to_s, (@day + 2.days).to_s, ["13:00:00", "18:00:00"])
    line.reload
    expect([line.start_date, line.end_date]).to eq [@day, @day + 2.days]
    expect([line.start_time, line.end_time]).to eq ["13:00:00", "18:00:00"]
  end
end
