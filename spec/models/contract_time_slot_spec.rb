require "rails_helper"

describe "handing over time slot reservations" do
  before :example do
    @pool = FactoryBot.create(:inventory_pool)
    @user = FactoryBot.create(:customer, inventory_pool: @pool)
    @manager = FactoryBot.create(:lending_manager, inventory_pool: @pool)
    @model = FactoryBot.create(:model)
    @item = FactoryBot.create(:item, model: @model, owner: @pool)
    @today = Time.zone.today
  end

  def reserve(start_time, end_time, day: @today, user: @user, **attrs)
    FactoryBot.create(:item_line,
      inventory_pool: @pool,
      user: user,
      model: @model,
      status: :approved,
      start_date: day,
      end_date: day,
      start_time: start_time,
      end_time: end_time,
      **attrs)
  end

  def hand_over(line, **options)
    Contract.sign!(@manager, @pool, @user, [line], "test", **options)
  end

  def time_in(minutes)
    (Time.zone.now + minutes.minutes).strftime("%H:%M:00")
  end

  it "is not handed over on another day than the one of its time slot" do
    line = reserve("10:00:00", "12:00:00",
      day: @pool.next_open_date(@today + 1.day), item: @item)
    expect { hand_over(line) }.to raise_error(/change the date of the reservation first/)
    expect(line.reload.status).to eq :approved
  end

  it "is not handed over after its time slot" do
    line = reserve("00:00:00", "00:01:00", item: @item)
    expect { hand_over(line) }.to raise_error(/is already over/)
    expect(line.reload.status).to eq :approved
  end

  it "keeps its time slot when handed over during the time slot" do
    line = reserve("00:00:00", "23:59:00", item: @item)
    hand_over(line)
    line.reload
    expect(line.status).to eq :signed
    expect([line.start_time, line.end_time]).to eq ["00:00:00", "23:59:00"]
  end

  context "before its time slot" do
    before :example do
      skip "needs some time left today" if Time.zone.now.strftime("%H:%M") > "23:30"
    end

    it "starts at the time of the hand over" do
      line = reserve("23:50:00", "23:59:00", item: @item)
      hand_over(line)
      line.reload
      expect(line.status).to eq :signed
      expect(line.start_time).to be <= Time.zone.now.strftime("%T")
      expect(line.end_time).to eq "23:59:00"
    end

    it "needs a confirmation if the item is reserved by somebody else before" do
      other_user = FactoryBot.create(:customer, inventory_pool: @pool)
      reserve(time_in(5), time_in(15), user: other_user)
      line = reserve("23:50:00", "23:59:00", item: @item)

      expect { hand_over(line) }.to raise_error(Contract::EarlyHandOverConflict)
      expect(line.reload.status).to eq :approved

      hand_over(line.reload, confirm_early_hand_over: true)
      expect(line.reload.status).to eq :signed
    end
  end
end
