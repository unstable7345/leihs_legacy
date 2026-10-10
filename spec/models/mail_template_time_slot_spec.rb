require "rails_helper"

describe "time slots in mail templates" do
  before :example do
    @pool = FactoryBot.create(:inventory_pool)
    @user = FactoryBot.create(:customer, inventory_pool: @pool)
    @model = FactoryBot.create(:model)
    @item = FactoryBot.create(:item, model: @model, owner: @pool)
    @day = @pool.next_open_date(Time.zone.today + 1.day)
  end

  def reserve(start_time = nil, end_time = nil)
    FactoryBot.create(:item_line,
      inventory_pool: @pool,
      user: @user,
      model: @model,
      item: @item,
      status: :approved,
      start_date: @day,
      end_date: @day,
      start_time: start_time,
      end_time: end_time)
  end

  def render(reservation)
    variables = MailTemplate.liquid_variables_for_user(@user, @pool, [reservation])
    Liquid::Template
      .parse("{% for l in reservations %}{{ l.model_name }}" \
             "{% if l.time_slot %} {{ l.time_slot }}{% endif %}{% endfor %}")
      .render(variables)
  end

  it "offers the time slot of a reservation" do
    expect(render(reserve("10:00:00", "12:00:00"))).to eq "#{@model.name} 10:00–12:00"
  end

  it "offers no time slot for a whole-day reservation" do
    expect(render(reserve)).to eq @model.name
  end
end
