const horaColombia = Duration(hours: -5);

DateTime soloDia(DateTime fecha) => DateTime.utc(fecha.year, fecha.month, fecha.day);

DateTime fechaEnGranja(DateTime momento) => soloDia(momento.toUtc().add(horaColombia));
