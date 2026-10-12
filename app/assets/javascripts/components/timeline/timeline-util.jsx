window.TimelineUtil = {

  isBefore(m1, m2) {
    return m1.isBefore(m2, 'day')
  },

  isAfter(m1, m2) {
    return m1.isAfter(m2, 'day')
  },

  daysDifference(m1, m2) {
    return m1.startOf('day').diff(m2.startOf('day'), 'days')
  },

  numberOfDays(firstMoment, lastMoment) {
    return this.daysDifference(lastMoment, firstMoment) + 1
  },

  offset(firstMoment) {
    return this.daysDifference(moment(), firstMoment)
  },

  late(r) {
    return r.status == 'signed' &&
      !r.returned_date && TimelineUtil.isBefore(moment(r.end_date), moment())
  },

  // "HH:MM" of a reservation by the hour, null for whole days
  timeSlotTime(t) {
    return t ? String(t).substr(0, 5) : null
  },

  timeSlotLabel(r) {
    if(!r.start_time) {
      return null
    }
    return TimelineUtil.timeSlotTime(r.start_time) + '\u2013' + TimelineUtil.timeSlotTime(r.end_time)
  },

  // The times a reservation by the hour takes on a day (["HH:MM:SS",
  // "HH:MM:SS"]): from its start time on its first day, until its end time on
  // its last day, the whole of the days between. Without a day, its times.
  dailyWindow(r, day) {
    if(!day) {
      return [r.start_time, r.end_time]
    }
    var d = moment(day).format('YYYY-MM-DD')
    return [
      d == moment(r.start_date).format('YYYY-MM-DD') ? r.start_time : '00:00:00',
      d == moment(r.end_date).format('YYYY-MM-DD') ? r.end_time : '24:00:00'
    ]
  },

  // The reservations of a day which need items at the same time: the whole-day
  // (and late) ones plus the ones by the hour of the most booked time window.
  concurrentReservations(reservations, day) {
    var isSlot = (r) => r.start_time && !TimelineUtil.late(r)
    var wholeDay = _.reject(reservations, isSlot)
    var slots = _.filter(reservations, isSlot)
    var overlap = (a, b) => {
      var wa = TimelineUtil.dailyWindow(a, day)
      var wb = TimelineUtil.dailyWindow(b, day)
      return wa[0] < wb[1] && wb[0] < wa[1]
    }
    var busiest = _.max(
      slots.map((w) => _.filter(slots, (r) => overlap(r, w))),
      (rs) => rs.length
    )
    return wholeDay.concat(_.isArray(busiest) ? busiest : [])
  },

  reserved(r) {
    return TimelineUtil.isAfter(moment(r.start_date), moment()) && r.item_id
  },

  findUser(timeline_availability, user_id) {
    return _.find(
      timeline_availability.reservation_users,
      (ru) => {
        return ru.id == user_id
      }
    )
  },

  username(timeline_availability, rr) {
    var u = TimelineUtil.findUser(timeline_availability, rr.user_id)
    var name = u.firstname
    if(u.lastname) {
      name += ' ' + u.lastname
    }
    return name
  },

  inventoryCode(timeline_availability, rr) {

    if(!rr.item_id) {
      return null
    }

    return _.find(
      timeline_availability.items,
      (i) => i.id == rr.item_id
    ).inventory_code
  }
}
