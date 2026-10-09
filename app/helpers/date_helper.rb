module DateHelper

  def interval(start_date, end_date)
    interval = Integer(end_date - start_date).abs + 1
    pluralize(interval, _('Day'), _('Days'))
  end

  # Date and time of day, e.g. "09.10.2026 14:32"
  def l_date_time(time)
    "#{l(time.to_date)} #{time.strftime('%H:%M')}"
  end

  # Date, with the time of day if given as "HH:MM:SS" (time slots)
  def l_date_with_time_of_day(date, time_of_day)
    [l(date), time_of_day.try(:first, 5)].compact.join(' ')
  end

end
