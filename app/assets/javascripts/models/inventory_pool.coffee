###
  
  InventoryPool

###

class window.App.InventoryPool extends Spine.Model

  @configure "InventoryPool", "id", "name", "default_contract_note", "borrow_reservation_advance_days"

  # The time slots for same-day reservations, as options of a select: value
  # "HH:MM:SS-HH:MM:SS", label "Morning (08:00–13:00)" (see time_slots)
  timeSlotOptions: ->
    _.map (@time_slots or []), (slot) ->
      value: "#{slot.start_time}-#{slot.end_time}"
      label: "#{slot.name} (#{slot.start_time[0..4]}–#{slot.end_time[0..4]})"

  @hasMany "availabilities", "App.Availability", "inventory_pool_id"
  @hasMany "models", "App.Model", "inventory_pool_id"
  @hasMany "holidays", "App.Holiday", "inventory_pool_id"
  @hasOne "workday", "App.Workday", "inventory_pool_id"

  @extend Spine.Model.Ajax

  @url: "/inventory_pools"

  isClosedOn: (date)=>
    _.include(@workday().closedDays(), date.day()) or
      _.any(@holidays().all(), (h)->
        (date.isAfter(h.start_date) and date.isBefore(h.end_date)) or
          date.isSame(h.start_date) or
          date.isSame(h.end_date)
      )

  isVisitPossible: (date)=>
    # NOTE check if the maximum visits limit has been reached
    @workday().reached_max_visits.indexOf(moment(date).format("YYYY-MM-DD")) is -1

  hasEnoughReservationAdvanceDays: (date)=>
    # NOTE check number of days between order submission and hand over
    date >= moment().startOf('day').add(@borrow_reservation_advance_days || 0, 'days')
