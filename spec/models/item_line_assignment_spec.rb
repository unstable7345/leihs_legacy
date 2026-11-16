require "rails_helper"

# A single item (a space like a BUC) assigned in advance to a reservation on
# another day can still be assigned and handed over for an earlier one.
describe "assigning an item already assigned to another reservation" do
  before :example do
    @pool = FactoryBot.create(:inventory_pool)
    @manager = FactoryBot.create(:lending_manager, inventory_pool: @pool)
    @user = FactoryBot.create(:customer, inventory_pool: @pool)
    @other_user = FactoryBot.create(:customer, inventory_pool: @pool)
    @model = FactoryBot.create(:model)
    @item = FactoryBot.create(:item, model: @model, owner: @pool)
    @today = Time.zone.today
  end

  def reserve(user, day, start_time = nil, end_time = nil, **attrs)
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

  def assign(line)
    line.reload
    line.item = @item
    line
  end

  it "assigns it for today if it is assigned to someone else tomorrow" do
    reserve(@other_user, @today + 1.day, "15:30:00", "16:30:00", item: @item)
    line = assign(reserve(@user, @today, "09:00:00", "14:00:00"))
    expect(line).to be_valid
  end

  it "assigns it for the same user on another day" do
    reserve(@user, @today + 7.days, item: @item)
    line = assign(reserve(@user, @today))
    expect(line).to be_valid
  end

  it "does not assign it if the other reservation overlaps" do
    reserve(@other_user, @today, "13:00:00", "15:00:00", item: @item)
    line = assign(reserve(@user, @today, "09:00:00", "14:00:00"))
    expect(line).not_to be_valid
  end

  it "assigns it right after the other reservation by the hour" do
    reserve(@other_user, @today, "14:00:00", "15:00:00", item: @item)
    line = assign(reserve(@user, @today, "09:00:00", "14:00:00"))
    expect(line).to be_valid
  end

  it "does not assign it while it is handed over to someone else" do
    out = reserve(@other_user, @today, item: @item)
    Contract.sign!(@manager, @pool, @other_user, [out], "test")
    line = assign(reserve(@user, @today + 3.days))
    expect(line).not_to be_valid
  end

  it "does not hand it over while someone else has it" do
    later = reserve(@other_user, @today + 1.day, item: @item)
    now = reserve(@user, @today, item: @item)
    Contract.sign!(@manager, @pool, @user, [now], "test")
    expect do
      Contract.sign!(@manager, @pool, @other_user, [later.reload], "test")
    end.to raise_error(ActiveRecord::RecordInvalid)
  end
end
