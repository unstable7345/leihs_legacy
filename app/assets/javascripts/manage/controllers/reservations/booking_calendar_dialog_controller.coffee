class window.App.ManageBookingCalendarDialogController extends App.BookingCalendarDialogController
    
  # overwrite
  setupModal: =>
    do @setupTimeSlots
    @dialog = $ App.Render "manage/views/booking_calendar/calendar_dialog", {user: @user},
      startDateDisabled: @startDateDisabled
      quantityDisabled: @quantityDisabled
      timeSlots: @timeSlots
      mixedTimeSlots: @initialTimeSlot == "keep"
    @listOfLines = @dialog.find("#booking-calendar-lines .list-of-lines")
    @partitionsEl = @dialog.find("#booking-calendar-partitions")
    @timeSlotEl = @dialog.find("#booking-calendar-time-slot")
    super
    @timeSlotEl.val @initialTimeSlot
    @timeSlotEl.on "change", =>
      # a time slot is always booked for a single day
      @endDateEl.val @startDateEl.val() if @getTimeWindow()?[0]
      # the calendar shows the availability of the chosen time slot
      @fetchAvailability().done => @bookingCalendar?.render()

  # The pool's time slots as options; the one of the reservations is selected
  # ("" = whole day, "keep" = they have different ones)
  setupTimeSlots: =>
    @timeSlots = App.InventoryPool.current.timeSlotOptions()
    values = _.uniq _.map(@reservations, (l)-> if l.start_time then "#{l.start_time}-#{l.end_time}" else "")
    @initialTimeSlot = if values.length == 1 then values[0] else "keep"
    if @initialTimeSlot not in ["", "keep"] and not _.find(@timeSlots, (o)=> o.value == @initialTimeSlot)
      # a time slot the pool doesn't offer anymore
      [start, end] = @initialTimeSlot.split("-")
      @timeSlots.push {value: @initialTimeSlot, label: "#{start[0..4]}–#{end[0..4]}"}

  # [start_time, end_time] of the selected time slot, [null, null] for whole
  # days, undefined to keep the time slots of the reservations
  getTimeWindow: =>
    value = @timeSlotEl?.val()
    return undefined if not value? or value == "keep"
    if value == "" then [null, null] else value.split("-")

  # overwrite
  setupDates: =>
    @startDateEl.val (_.min @reservations, (l)-> Date.parse l.start_date).start_date
    @endDateEl.val (_.max @reservations, (l)-> Date.parse l.end_date).end_date

  # overwrite
  fetchData: =>
    @fetchWorkdays().done => do @initalizeDialog
    @fetchHolidays().done => do @initalizeDialog
    @fetchPartitions().done => @fetchGroups().done => do @initalizeDialog
    if _.any(@models, (m)-> not m.availability?()?) or @getTimeWindow()?[0]
      @fetchAvailability().done => do @initalizeDialog
    else
      @availabilities = true

  # including the availability of the chosen time slot (see changes_by_window)
  fetchAvailability: =>
    [startTime, endTime] = @getTimeWindow() or []
    App.Availability.ajaxFetch
      data: $.param
        model_ids: _.map @models, (m)-> m.id
        user_id: @user.id
        start_time: startTime
        end_time: endTime
    .done => @availabilities = true

  fetchPartitions: =>
    App.Partition.ajaxFetch
      data: $.param
        model_ids: _.map @models, (m)-> m.id
    .done (data)=> 
      @partitions = (App.Partition.find "#{datum.model_id}#{datum.inventory_pool_id}#{datum.group_id}" for datum in data)

  fetchGroups: =>
    App.Group.ajaxFetch
      data: $.param
        group_ids: _.compact _.uniq(_.map @partitions, (p)-> p.group_id)
    .done (data)=> 
      @groups = (App.Group.find datum.id for datum in data)
      do @setupPartitions

  # overwrite
  initalizeDialog: =>
    return false unless @workdays and @holidays and @availabilities and @partitions and @groups
    super

  setupPartitions: =>
    data = {user: [], userGroups: [], otherGroups: []}
    data.user = @user.groupIds

    for partition in @partitions
      if partition.group_id?
        if _.include(@user.groupIds, partition.group_id) and not data.userGroups.map((g) => g.id).includes partition.group_id
          data.userGroups.push partition.group()
        else if not data.otherGroups.map((g) => g.id).includes partition.group_id
          data.otherGroups.push partition.group()

    data.userGroups = _.sortBy(data.userGroups, (g) => g.name)
    data.otherGroups = _.sortBy(data.otherGroups, (g) => g.name)

    @partitionsEl.html App.Render "manage/views/booking_calendar/partitions", data

  setupBookingCalendar: =>
    @bookingCalendar = new App.ManageBookingCalendar
      calendarEl: @dialog.find "#booking-calendar"
      startDateEl: @startDateEl
      startDateDisabled: @startDateDisabled
      endDateEl: @endDateEl
      quantityEl: @dialog.find "#booking-calendar-quantity"
      groupIds: @user.groupIds
      partitions: @partitions
      reservations: @reservations
      models: @models
      getTimeWindow: @getTimeWindow
      renderFunctionCallback: @calendarRendered

  calendarRendered: =>
    options =
      groupIds: @user.groupIds
      start_date: moment(@startDateEl.val(), i18n.date.L)
      end_date: moment(@endDateEl.val(), i18n.date.L)
      quantity: @getQuantity()
    @listOfLines.html App.Render "manage/views/booking_calendar/line", @mergedLines, options

  # overwrite
  getSelectedInventoryPool: => App.InventoryPool.current

  # overwrite
  validationAlerts: =>
    # NOTE this are just warnings (not preventing as error) # TODO dry with super valid()
    ip = @getSelectedInventoryPool()
    errors = []
    if not ip.isVisitPossible @getStartDate()
      errors.push _jed("Booking is no longer possible on this start date")
    if not ip.isVisitPossible @getEndDate()
      errors.push _jed("Booking is no longer possible on this end date")
    if ip.isClosedOn @getStartDate()
      errors.push _jed("Inventory pool is closed on start date")
    if ip.isClosedOn @getEndDate()
      errors.push _jed("Inventory pool is closed on end date")

    if errors.length
      @showError errors.join(", ")
    else
      @errorsContainer.html ""

  valid: =>
    if @getTimeWindow()?[0] and not @getStartDate().isSame(@getEndDate(), "day")
      @showError _jed("A time slot can only be reserved for a single day")
      false
    else
      true

  store: => # virtual
