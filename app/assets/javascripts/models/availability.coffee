###
  
  Availability

  more complex availability (including changes)
  needed for the booking calendar

###

class window.App.Availability extends Spine.Model

  @configure "Availability", "inventory_pool_id", "model_id", "changes", "changes_by_window", "changes_by_period", "total_borrowable", "total_rentable", "in_stock"
  
  @belongsTo "inventory_pool", "App.InventoryPool", "inventory_pool_id"
  @belongsTo "model", "App.Model", "model_id"

  @extend Spine.Model.Ajax

  constructor: (data)->
    super

  # The availabilities to check for a line: the one of its times on each day,
  # or for a whole-day line (and one over night, e.g. from 16:00 to 10:00 the
  # next day) the one of every window booked (see changes_by_window)
  forTimeWindow: (startTime, endTime, startDate, endDate) ->
    # a reservation by the hour over several days: exactly for its period
    if startTime? and startDate? and endDate? and startDate != endDate
      periodKey = "#{startDate} #{startTime}/#{endDate} #{endTime}"
      if @changes_by_period?[periodKey]?
        return _.map @changes_by_period[periodKey], (changes) =>
          clone = $.extend true, {}, @
          clone.changes = changes
          clone
    byWindow = @changes_by_window or {}
    keys = if startTime? and startTime < endTime then ["#{startTime}-#{endTime}"] else _.keys(byWindow)
    windowed = _.compact _.map keys, (key) =>
      if byWindow[key]?
        clone = $.extend true, {}, @
        clone.changes = byWindow[key]
        clone
    if windowed.length then windowed else [@]

  availabilityForGroups: (change, groupIds) ->
    _.reduce change[2], ((mem, partition)=> if @groupIsIn(groupIds, partition.group_id) then mem+partition.in_quantity else mem), 0 

  changesBetween: (startDate, endDate)->
    startDate = @mostRecentOrEqualDate startDate
    _.filter @changes, (change)-> moment(change[0]).diff(moment(startDate), "days") >= 0 and moment(change[0]).diff(moment(endDate), "days") <= 0

  groupIsIn: (groupIds, groupId) -> 
    result = _.include(groupIds, groupId) or groupId == 0 or groupId == null
    result

  maxAvailableForGroups: (startDate, endDate, groupIds)->
    min = _.min @changesBetween(startDate, endDate), (change)=> @availabilityForGroups(change, groupIds)
    if min?
      _.reduce min[2], ((mem, partition) => 
        if @groupIsIn(groupIds, partition.group_id) then mem+partition.in_quantity else mem
      ), 0
    else
      0

  maxAvailableInTotal: (startDate, endDate) ->
    changes = @changesBetween(startDate, endDate)
    if changes.length
      _.min(changes, (change)-> change[1])[1]
    else
      0

  mostRecentOrEqualDate: (date) -> 
    changesOfPastOrEqual = _.filter @changes, (change)-> moment(change[0]).diff(date, "days") <= 0
    if changesOfPastOrEqual.length
      min = moment(_.min(changesOfPastOrEqual, (change)-> return Math.abs moment(date).diff(change[0], "days"))[0]).toDate()
    else
      min = date
    return min

  unavailableRanges: (quantity, groupIds, startDate, endDate) ->
    changes = @changesBetween(startDate, endDate)
    unavailableRanges = []
    _.each changes, (change, i)=>
      availableQuantity = if groupIds then @availabilityForGroups(change, groupIds) else change[1] # get total quantity when groupIds are not defined
      if availableQuantity < quantity
        nextChange = changes[i+1]
        rangeStartDate = if moment(change[0]).diff(moment(startDate), "days") > 0 then change[0] else startDate
        rangeEndDate = if nextChange? then moment(nextChange[0]).subtract(1, "days") else endDate
        unavailableRanges.push
          startDate: moment(rangeStartDate).toDate()
          endDate: moment(rangeEndDate).toDate()
    if unavailableRanges.length
      merge = (i, ranges)->
        range = ranges[i]
        nextRange = ranges[i+1]
        if nextRange? and moment(nextRange.startDate).diff(moment(range.endDate), "days") == 1
          ranges[i] = 
            startDate: range.startDate
            endDate: nextRange.endDate
          ranges.splice i+1, 1
          merge i, ranges
      merge 0, unavailableRanges
      return unavailableRanges

  ###
    solves the self-blocking problem 
    excludes the given reservations from the changes
    if it is not possible to solve the self-blocking problem with just adding the line quantity again
    take care to deep clone the availability to not manipulate the original
  ###
  withoutLines: (reservations, recoverSoftOverBooking) ->
    clone = $.extend true, {}, @
    _.each clone.changes, (change)=>
      for allocation in change[2]
        for line in reservations
          # ItemLine is the only type we have
          if allocation.running_reservations?
            outDocumentLines = allocation.running_reservations
            if _.include(outDocumentLines, line.id)
              allocation.running_reservations = _.filter outDocumentLines, (l)-> l != line.id
              # we recover the quantity only if is not a soft-overbooking
              # or if it is request by passing true as second argument
              if recoverSoftOverBooking or @groupIsIn line.user().groupIds, allocation.group_id
                # total quantity
                change[1] += line.quantity
                # partition based quantity
                allocation.in_quantity += line.quantity
      return change
    return clone