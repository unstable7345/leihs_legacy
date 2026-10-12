require "rails_helper"

describe "availability of time slot reservations" do
  before :example do
    @pool = FactoryBot.create(:inventory_pool)
    @user = FactoryBot.create(:customer, inventory_pool: @pool)
    @manager = FactoryBot.create(:lending_manager, inventory_pool: @pool)
    @model = FactoryBot.create(:model)
    @item = FactoryBot.create(:item, model: @model, owner: @pool)
    @day = @pool.next_open_date(Time.zone.today + 1.day)
  end

  def reserve(start_time = nil, end_time = nil, day: @day, end_day: day, **attrs)
    FactoryBot.create(:item_line,
      inventory_pool: @pool,
      user: @user,
      model: @model,
      status: :approved,
      start_date: day,
      end_date: end_day,
      start_time: start_time,
      end_time: end_time,
      **attrs)
  end

  # handed over during its time slot, which is over in the meantime
  def hand_over_and_let_time_slot_end(day)
    line = reserve("00:00:00", "23:59:00", day: day, item: @item)
    Contract.sign!(@manager, @pool, @user, [line], "test")
    line.update_columns(end_time: "00:01:00")
    line.reload
  end

  it "lends the same item in the morning and in the afternoon" do
    morning = reserve("08:00:00", "13:00:00")
    afternoon = reserve("13:00:00", "18:00:00")
    expect(morning.reload).to be_available
    expect(afternoon.reload).to be_available
  end

  it "does not lend the item for the whole day if it is reserved for a time slot" do
    reserve("08:00:00", "13:00:00")
    whole_day = reserve
    expect(whole_day.reload).not_to be_available
  end

  # by the hour over several days, e.g. from 16:00 to 10:00 the next day
  def reserve_over_days(start_time, end_time)
    reserve(start_time, end_time, end_day: @day + 1.day).reload
  end

  it "keeps the times of a reservation by the hour over several days" do
    line = reserve_over_days("16:00:00", "10:00:00")
    expect(line.start_time).to eq "16:00:00"
    expect(line.end_time).to eq "10:00:00"
    expect(line.end_date).to eq @day + 1.day
  end

  it "makes a reservation ending before its start a whole-day one" do
    line = reserve("16:00:00", "18:00:00")
    line.update!(start_date: @day + 1.day, end_date: @day + 1.day,
                 start_time: "16:00:00", end_time: "10:00:00")
    expect(line.reload.start_time).to be_nil
  end

  it "lends the item before and after a reservation over several days" do
    reserve_over_days("16:00:00", "10:00:00")
    before = reserve("10:00:00", "16:00:00")
    after = reserve("10:00:00", "12:00:00", day: @day + 1.day)
    expect(before.reload).to be_available
    expect(after.reload).to be_available
  end

  it "does not lend the item during a reservation over several days" do
    reserve_over_days("16:00:00", "10:00:00")
    evening = reserve("17:00:00", "19:00:00")
    morning = reserve("09:00:00", "11:00:00", day: @day + 1.day)
    whole_next_day = reserve(day: @day + 1.day)
    expect(evening.reload).not_to be_available
    expect(morning.reload).not_to be_available
    expect(whole_next_day.reload).not_to be_available
  end

  it "lends one of two items for a period with two short reservations in it" do
    FactoryBot.create(:item, model: @model, owner: @pool)
    reserve("09:00:00", "10:00:00")
    reserve("12:00:00", "13:00:00")
    long = reserve("09:00:00", "13:00:00")
    expect(long.reload).to be_available
    too_many = reserve("09:30:00", "12:30:00")
    expect(too_many.reload).not_to be_available
  end

  it "does not lend the item for overlapping time slots" do
    reserve("08:00:00", "13:00:00")
    overlapping = reserve("12:00:00", "14:00:00")
    expect(overlapping.reload).not_to be_available
  end

  it "counts an item not returned after its time slot as missing for the rest of the day" do
    today = Time.zone.today
    handed_over = hand_over_and_let_time_slot_end(today)
    expect(handed_over.status).to eq :signed
    expect(handed_over.start_time).to eq "00:00:00"

    later = reserve("23:58:00", "23:59:00", day: today)
    expect(later.reload).not_to be_available
  end

  it "does not count an item returned in time" do
    today = Time.zone.today
    handed_over = hand_over_and_let_time_slot_end(today)
    ApplicationRecord.transaction do
      handed_over.reload.update!(returned_date: today,
        returned_at: Time.zone.now,
        returned_to_user_id: @manager.id)
      handed_over.contract.update!(state: :closed)
    end

    later = reserve("23:58:00", "23:59:00", day: today)
    expect(later.reload).to be_available
  end
end
