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

  // "HH:MM" of a time slot reservation, null for whole days
  timeSlotTime(t) {
    return t ? String(t).substr(0, 5) : null
  },

  timeSlotLabel(r) {
    if(!r.start_time) {
      return null
    }
    return TimelineUtil.timeSlotTime(r.start_time) + '\u2013' + TimelineUtil.timeSlotTime(r.end_time)
  },

  // The reservations of a day which need items at the same time: the whole-day
  // (and late) ones plus the time slot ones of the most booked time window.
  concurrentReservations(reservations) {
    var isSlot = (r) => r.start_time && !TimelineUtil.late(r)
    var wholeDay = _.reject(reservations, isSlot)
    var slots = _.filter(reservations, isSlot)
    var overlap = (a, b) => a.start_time < b.end_time && b.start_time < a.end_time
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
