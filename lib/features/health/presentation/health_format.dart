const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
const _months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

String p2(int n) => n.toString().padLeft(2, '0');

String friendlyDateTime(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} de ${_months[d.month - 1]} • ${p2(d.hour)}:${p2(d.minute)}';

String friendlyDate(DateTime d) => '${d.day} de ${_months[d.month - 1]} de ${d.year}';

/// Formata centavos como moeda brasileira: 25000 -> "R$ 250,00".
String brl(int cents) {
  final negative = cents < 0;
  final value = cents.abs();
  final digits = (value ~/ 100).toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}R\$ $buffer,${p2(value % 100)}';
}
