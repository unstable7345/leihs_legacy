require "rails_helper"

describe "time slots in lending" do
  before :example do
    @pool = FactoryBot.create(:inventory_pool)
    @user = FactoryBot.create(:customer, inventory_pool: @pool)
    @manager = FactoryBot.create(:lending_manager, inventory_pool: @pool)
    @model = FactoryBot.create(:model)
    FactoryBot.create(:item, model: @model, owner: @pool)
    TimeSlot.create!(inventory_pool: @pool, name: "Afternoon", start_time: "13:00", end_time: "18:00")
    TimeSlot.create!(inventory_pool: @pool, name: "Morning", start_time: "08:00", end_time: "13:00")
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

  it "lists the time slots of a pool by start time" do
    expect(@pool.time_slots.map(&:name)).to eq ["Morning", "Afternoon"]
    expect(@pool.time_slots.first.as_json)
      .to eq(name: "Morning", start_time: "08:00:00", end_time: "13:00:00")
  end

  describe "changing the time line" do
    it "makes a reservation a single-day one of a time slot" do
      line = reserve
      line.update_time_line(@day, @day + 1.day, @manager, ["08:00:00", "13:00:00"])
      line.reload
      expect([line.start_date, line.end_date]).to eq [@day, @day]
      expect([line.start_time, line.end_time]).to eq ["08:00:00", "13:00:00"]
    end

    it "makes a time slot reservation a whole-day one" do
      line = reserve(end_date: @day, start_time: "08:00:00", end_time: "13:00:00")
      line.update_time_line(@day, @day + 1.day, @manager, [nil, nil])
      line.reload
      expect([line.start_time, line.end_time]).to eq [nil, nil]
      expect(line.end_date).to eq @day + 1.day
    end

    it "keeps the time slot when not given" do
      line = reserve(end_date: @day, start_time: "08:00:00", end_time: "13:00:00")
      line.update_time_line(@day, @day, @manager)
      expect(line.reload.start_time).to eq "08:00:00"
    end
  end

  describe "the time slot of the params" do
    it "is a time slot the pool offers" do
      expect(controller_with(start_time: "08:00:00", end_time: "13:00:00").send(:time_window_param))
        .to eq ["08:00:00", "13:00:00"]
    end

    it "is the whole day when blank, unchanged when missing" do
      expect(controller_with(start_time: "", end_time: "").send(:time_window_param)).to eq [nil, nil]
      expect(controller_with({}).send(:time_window_param)).to eq :keep
    end

    it "is refused when the pool doesn't offer it" do
      expect { controller_with(start_time: "09:00:00", end_time: "10:00:00").send(:time_window_param) }
        .to raise_error(/does not offer this time slot/)
    end
  end

  describe "the availability of a requested time slot" do
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

    it "is computed for a time slot without reservations" do
      reserve(start_date: @day, end_date: @day, start_time: "08:00:00", end_time: "13:00:00")
      controller = availability_controller(start_time: "13:00:00", end_time: "18:00:00")
      window = controller.send(:requested_time_window)
      expect(window).to eq ["13:00:00", "18:00:00"]

      by_window = controller.send(:changes_by_window, @model, window)
      # the morning reservation doesn't take the item in the afternoon
      expect(available_on(by_window["13:00:00-18:00:00"], @day)).to eq 1
      expect(available_on(by_window["08:00:00-13:00:00"], @day)).to eq 0
    end

    it "counts whole-day reservations" do
      reserve(start_date: @day, end_date: @day)
      controller = availability_controller(start_time: "13:00:00", end_time: "18:00:00")
      by_window = controller.send(:changes_by_window, @model, controller.send(:requested_time_window))
      expect(available_on(by_window["13:00:00-18:00:00"], @day)).to eq 0
    end

    it "ignores a malformed time slot" do
      expect(availability_controller(start_time: "", end_time: "").send(:requested_time_window)).to be_nil
      expect(availability_controller(start_time: "13:00; DROP", end_time: "18:00:00")
               .send(:requested_time_window)).to be_nil
    end
  end

  it "creates a reservation of a time slot" do
    controller = controller_with({})
    controller.define_singleton_method(:group_manager?) { false }
    line = controller.send(:create_reservation,
      @user, nil, @pool, :approved, @model, 1,
      @day.to_s, (@day + 2.days).to_s, ["13:00:00", "18:00:00"])
    line.reload
    expect([line.start_date, line.end_date]).to eq [@day, @day]
    expect([line.start_time, line.end_time]).to eq ["13:00:00", "18:00:00"]
  end
end
