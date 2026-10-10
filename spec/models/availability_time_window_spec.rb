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

  def reserve(start_time = nil, end_time = nil, day: @day, **attrs)
    FactoryBot.create(:item_line,
      inventory_pool: @pool,
      user: @user,
      model: @model,
      status: :approved,
      start_date: day,
      end_date: day,
      start_time: start_time,
      end_time: end_time,
      **attrs)
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

  it "does not lend the item for overlapping time slots" do
    reserve("08:00:00", "13:00:00")
    overlapping = reserve("12:00:00", "14:00:00")
    expect(overlapping.reload).not_to be_available
  end

  it "counts an item not returned after its time slot as missing for the rest of the day" do
    today = Time.zone.today
    handed_over = reserve("00:00:00", "00:01:00", day: today, item: @item)
    Contract.sign!(@manager, @pool, @user, [handed_over], "test")
    expect(handed_over.reload.status).to eq :signed
    expect(handed_over.start_time).to eq "00:00:00"

    later = reserve("23:58:00", "23:59:00", day: today)
    expect(later.reload).not_to be_available
  end

  it "does not count an item returned in time" do
    today = Time.zone.today
    handed_over = reserve("00:00:00", "00:01:00", day: today, item: @item)
    Contract.sign!(@manager, @pool, @user, [handed_over], "test")
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
