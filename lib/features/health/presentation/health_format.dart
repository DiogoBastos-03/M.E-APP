const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
const _months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

String p2(int n) => n.toString().padLeft(2, '0');

String friendlyDateTime(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} de ${_months[d.month - 1]} • ${p2(d.hour)}:${p2(d.minute)}';

String friendlyDate(DateTime d) => '${d.day} de ${_months[d.month - 1]} de ${d.year}';
