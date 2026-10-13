window.App ?= {}

# Durations of reservations by the hour
App.Duration =
  minutes: (firstDate, secondDate, startTime, endTime) ->
    at = (date, time) -> moment("#{moment(date).format("YYYY-MM-DD")} #{time}", "YYYY-MM-DD HH:mm:ss")
    at(secondDate, endTime).diff(at(firstDate, startTime), "minutes")

  # e.g. "4 Hours", "1.5 Hours" (lowercase like "1 day" in the lists)
  hoursText: (minutes, lowercase = false) ->
    hours = Math.round(minutes / 30) / 2
    n = if hours == 1 then 1 else 2
    unit = if lowercase then _jed(n, 'hour', 'hours') else _jed(n, 'Hour', 'Hours')
    "#{hours} #{unit}"

$.views.tags

  diffDates: (firstDate, secondDate) ->
    if moment(secondDate).startOf("day").diff(moment(firstDate).startOf("day"), "days") < 1
      _jed("Today")
    else
      moment(firstDate).startOf("day").from(moment(secondDate).startOf("day"))

  # The duration of a reservation: in hours for one by the hour (from the
  # start time of the first day to the end time of the last), else in days
  diffDatesInDays: (firstDate, secondDate, startTime, endTime) ->
    if startTime and endTime
      App.Duration.hoursText(App.Duration.minutes(firstDate, secondDate, startTime, endTime))
    else
      days = moment(secondDate).endOf("day").diff(moment(firstDate).startOf("day"), "days") + 1
      "#{days} #{_jed(days, 'Day', _jed('Days'))}"


  diffToday: (date) ->
    if moment().startOf("day").diff(moment(date).startOf("day"), "days") == 0
      _jed("Today")
    else
      moment(date).startOf("day").from(moment().startOf("day"))

  todayOrDate: (date) ->
    if moment().startOf("day").diff(moment(date).startOf("day"), "days") < 1
      _jed("Today")
    else
      moment(date).startOf("day").from(moment().startOf("day"))

  date: (date)-> moment(date).format(i18n.date.L)

  day: (date)-> moment(date).format("dddd")

  dateAndTime: (date) ->
    "#{$.views.tags.diffToday.render(date)} #{moment(date).format("LT")}"
