###
  
  InventoryPool

###

class window.App.InventoryPool extends Spine.Model

  @configure "InventoryPool", "id", "name", "default_contract_note", "borrow_reservation_advance_days"

  # The times of reservations by the hour as options of a select: value
  # "HH:MM:SS", label "HH:MM", from the start to the end of the hours of the
  # pool in steps of 30 minutes; empty if it only offers whole days (see
  # hourly_time_options)
  timeOptions: ->
    _.map (@hourly_time_options or []), (time) -> {value: time, label: time[0..4]}

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
