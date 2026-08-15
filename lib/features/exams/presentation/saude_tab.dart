import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../access/presentation/access_controller.dart';
import '../../access/presentation/widgets/access_common.dart';
import '../../documents/data/medical_document_models.dart';
import '../../documents/presentation/document_detail_screen.dart';
import '../../documents/presentation/document_status_chip.dart';
import '../../documents/presentation/medical_documents_controller.dart';
import '../../documents/presentation/type_filter_dropdown.dart';
import '../../health/data/history_models.dart';
import '../../health/presentation/consulta_detail_screen.dart';
import '../../health/presentation/health_format.dart';
import '../../health/presentation/history_controller.dart';
import '../../health/presentation/rating_sheet.dart';
import '../../health/presentation/schedule_screen.dart';
import '../../home/data/home_models.dart';
import '../../home/presentation/home_controller.dart';
import '../data/exam_models.dart';
import 'exam_detail_screen.dart';
import 'exams_controller.dart';

const _monthsAbbr = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
String _fmtShort(DateTime? d) => d == null ? '' : '${d.day} ${_monthsAbbr[d.month - 1]} ${d.year}';

/// Aba Saúde. Por ora, só a seção "Exames" é funcional.
class SaudeTab extends StatefulWidget {
  const SaudeTab({super.key});
  @override
  State<SaudeTab> createState() => _SaudeTabState();
}

class _SaudeTabState extends State<SaudeTab> {
  int _segment = 0; // 0 Exames, 1 Consultas, 2 Histórico

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saúde',
                    style: GoogleFonts.poppins(
                        fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.6)),
                const SizedBox(height: 4),
                Text('Seus exames, consultas e histórico clínico.',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                _Segmented(
                  index: _segment,
                  labels: const ['Documentos', 'Consultas', 'Histórico'],
                  onChanged: (i) => setState(() => _segment = i),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: IndexedStack(
              index: _segment,
              children: const [
                _UnifiedDocsView(),
                _ConsultasView(),
                _HistoricoView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Documentos + Exames (lista unificada)
// --------------------------------------------------------------------------- //
const _filterOptions = <TypeFilterOption>[
  TypeFilterOption('all', 'Todos'),
  TypeFilterOption('RECEITA_SIMPLES', 'Receita simples'),
  TypeFilterOption('RECEITA_CONTROLE_ESPECIAL', 'Receita de controle especial'),
  TypeFilterOption('ATESTADO', 'Atestado'),
  TypeFilterOption('PEDIDO_EXAME', 'Pedido de exame'),
  TypeFilterOption('SOLICITACAO_PROCEDIMENTO', 'Solicitação de procedimento'),
  TypeFilterOption('exam', 'Resultado de exame'),
];

/// Item da lista unificada: um documento médico OU um resultado de exame.
class _SaudeItem {
  const _SaudeItem._(this.date, this.doc, this.exam);
  final DateTime date;
  final MedicalDocument? doc;
  final ExamResult? exam;
  factory _SaudeItem.doc(MedicalDocument d) => _SaudeItem._(d.issuedAt, d, null);
  factory _SaudeItem.exam(ExamResult e) => _SaudeItem._(e.resultDate ?? e.createdAt, null, e);
  bool get isDoc => doc != null;
}

class _UnifiedDocsView extends StatefulWidget {
  const _UnifiedDocsView();
  @override
  State<_UnifiedDocsView> createState() => _UnifiedDocsViewState();
}

class _UnifiedDocsViewState extends State<_UnifiedDocsView> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final docsC = context.watch<MedicalDocumentsController>();
    final examsC = context.watch<ExamsController>();

    final items = <_SaudeItem>[
      for (final d in docsC.documents) _SaudeItem.doc(d),
      for (final e in examsC.exams) _SaudeItem.exam(e),
    ]..sort((a, b) => b.date.compareTo(a.date));

    final filtered = items.where((it) {
      if (_filter == 'all') return true;
      if (_filter == 'exam') return !it.isDoc;
      return it.isDoc && it.doc!.documentType == _filter;
    }).toList();

    final loading = docsC.state == Loading.loading || examsC.state == Loading.loading;
    final bothError = docsC.state == Loading.error && examsC.state == Loading.error;

    Widget body;
    if (loading && items.isEmpty) {
      body = const LoadingState();
    } else if (bothError) {
      body = ErrorState(
        message: docsC.error ?? examsC.error ?? 'Erro',
        onRetry: () {
          docsC.load();
          examsC.load();
        },
      );
    } else if (filtered.isEmpty) {
      body = EmptyState(
        title: items.isEmpty ? 'Você ainda não tem documentos ou exames' : 'Nada neste filtro',
        message: items.isEmpty
            ? 'Receitas, atestados, pedidos e resultados de exame aparecem aqui.'
            : 'Nenhum item deste tipo. Tente outro filtro acima.',
        icon: Icons.folder_open_outlined,
      );
    } else {
      body = Column(
        children: [
          for (final it in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: it.isDoc
                  ? _DocumentCard(doc: it.doc!, controller: docsC)
                  : _ExamRowCard(exam: it.exam!),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: TypeFilterDropdown(
            options: _filterOptions,
            selectedKey: _filter,
            onChanged: (k) => setState(() => _filter = k),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.brand,
            onRefresh: () async {
              await Future.wait([docsC.load(), examsC.load()]);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [body],
            ),
          ),
        ),
      ],
    );
  }
}

/// Card de resultado de exame na lista unificada: título "Resultado de exame",
/// subtítulo "tipo do exame · data".
class _ExamRowCard extends StatelessWidget {
  const _ExamRowCard({required this.exam});
  final ExamResult exam;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExamDetailScreen(
            exam: exam,
            controller: context.read<ExamsController>(),
            publisher: context.read<AccessController>().doctorNameByUserId(exam.uploadedByUserId) ??
                'Profissional autorizado',
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppColors.border),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.science_outlined, color: AppColors.brandDark, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text('Resultado de exame',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.text)),
                      ),
                      if (exam.isNew) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: AppColors.brandTint, borderRadius: BorderRadius.circular(999)),
                          child: Text('Novo',
                              style: GoogleFonts.poppins(
                                  fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.brandDark)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('${exam.examType}  ·  ${_fmtShort(exam.resultDate ?? exam.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (exam.hasFile)
              const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.textSecondary),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.doc, required this.controller});
  final MedicalDocument doc;
  final MedicalDocumentsController controller;

  @override
  Widget build(BuildContext context) {
    final doctorName = controller.doctorNameFor(doc);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentDetailScreen(
            document: doc,
            controller: controller,
            doctorName: doctorName,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppColors.border),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(14)),
              child: Icon(doc.typeIcon, color: AppColors.brandDark, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(doc.typeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.text)),
                      ),
                      const SizedBox(width: 8),
                      DocumentStatusChip(doc: doc),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('$doctorName  ·  ${_fmtShort(doc.issuedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (doc.hasPdf)
              const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.textSecondary),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Segmento + placeholder
// --------------------------------------------------------------------------- //
class _Segmented extends StatelessWidget {
  const _Segmented({required this.index, required this.labels, required this.onChanged});
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.section,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.brand : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(labels[i],
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: i == index ? Colors.white : AppColors.textSecondary,
                      )),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Consultas
// --------------------------------------------------------------------------- //
class _ConsultasView extends StatelessWidget {
  const _ConsultasView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<HistoryController>();
    final access = context.read<AccessController>();
    final patientId = context.read<HomeController>().patient?.id ??
        c.history?.medicalRecord?.patientId;

    Widget body;
    if (c.state == Loading.loading) {
      body = const LoadingState();
    } else if (c.state == Loading.error) {
      body = ErrorState(message: c.error ?? 'Erro', onRetry: c.load);
    } else {
      final upcoming = c.upcoming;
      final past = c.past;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (upcoming.isEmpty && past.isEmpty)
            const EmptyState(
              title: 'Nenhuma consulta',
              message: 'Agende sua primeira consulta no botão acima.',
              icon: Icons.event_outlined,
            ),
          if (upcoming.isNotEmpty) ...[
            const _SectionLabel('PRÓXIMAS'),
            for (final a in upcoming)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ConsultaCard(
                    appt: a, access: access, summary: c.summaryFor(a.id), history: c),
              ),
          ],
          if (past.isNotEmpty) ...[
            const SizedBox(height: 6),
            const _SectionLabel('ANTERIORES'),
            for (final a in past)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ConsultaCard(
                    appt: a, access: access, summary: c.summaryFor(a.id), history: c),
              ),
          ],
        ],
      );
    }

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: c.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: (patientId == null || patientId.isEmpty)
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ScheduleScreen(controller: c, patientId: patientId),
                      )),
              icon: const Icon(Icons.add),
              label: const Text('Agendar consulta'),
            ),
          ),
          const SizedBox(height: 18),
          body,
        ],
      ),
    );
  }
}

class _ConsultaCard extends StatelessWidget {
  const _ConsultaCard({
    required this.appt,
    required this.access,
    required this.summary,
    required this.history,
  });
  final Appointment appt;
  final AccessController access;
  final ConsultationSummary? summary;
  final HistoryController history;

  ({String label, Color bg, Color fg, Color dot}) _statusChip() {
    if (appt.isPaymentPending) {
      return (label: 'Pagamento pendente', bg: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309), dot: AppColors.statePending);
    }
    switch (appt.status) {
      case ApptStatus.completed:
        return (label: 'Concluída', bg: AppColors.section, fg: AppColors.textSecondary, dot: AppColors.textSecondary);
      case ApptStatus.canceled:
        return (label: 'Cancelada', bg: AppColors.brandTint, fg: AppColors.stateDanger, dot: AppColors.stateDanger);
      case ApptStatus.scheduled:
      case ApptStatus.unknown:
        return (label: 'Agendada', bg: AppColors.tealTint, fg: AppColors.tealDark, dot: AppColors.tealDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = access.doctorNameById(appt.doctorId) ?? 'Médico(a)';
    final st = _statusChip();
    final hasSummary = summary != null;

    return GestureDetector(
      onTap: hasSummary
          ? () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ConsultaDetailScreen(appointment: appt, summary: summary!, doctorName: doctor),
              ))
          : null,
      child: AccessCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(14)),
                  child: Icon(appt.type.icon, color: AppColors.brandDark, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.text)),
                      const SizedBox(height: 2),
                      Text(friendlyDateTime(appt.start),
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                StatusChip(label: st.label, background: st.bg, foreground: st.fg, dot: st.dot),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _TypePill(type: appt.type),
                const Spacer(),
                if (hasSummary)
                  Row(children: [
                    Text('Ver resumo',
                        style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.brand)),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.brand),
                  ]),
              ],
            ),
            if (appt.status == ApptStatus.completed) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 10),
              _reviewRow(context, doctor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(BuildContext context, String doctor) {
    final review = history.reviewFor(appt.id);

    if (review == null) {
      return Row(
        children: [
          Text('Como foi sua consulta?',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
          const Spacer(),
          GestureDetector(
            onTap: () => showRatingSheet(
              context,
              controller: history,
              appointmentId: appt.id,
              doctorName: doctor,
            ),
            child: Text('Avaliar',
                style: GoogleFonts.poppins(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.brand)),
          ),
        ],
      );
    }

    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= review.rating ? Icons.star_rounded : Icons.star_border_rounded,
            size: 16,
            color: i <= review.rating ? AppColors.statePending : AppColors.textSecondary,
          ),
        const Spacer(),
        GestureDetector(
          onTap: () => showRatingSheet(
            context,
            controller: history,
            appointmentId: appt.id,
            doctorName: doctor,
          ),
          child: Text('Editar avaliação',
              style: GoogleFonts.poppins(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.brand)),
        ),
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});
  final AppointmentType type;

  @override
  Widget build(BuildContext context) {
    final tele = type == AppointmentType.telemedicine;
    final bg = tele ? AppColors.tealTint : AppColors.section;
    final fg = tele ? AppColors.tealDark : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(type.icon, size: 13, color: fg),
        const SizedBox(width: 5),
        Text(type.label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      ]),
    );
  }
}

// --------------------------------------------------------------------------- //
// Histórico clínico
// --------------------------------------------------------------------------- //
class _HistoricoView extends StatelessWidget {
  const _HistoricoView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<HistoryController>();
    final access = context.read<AccessController>();

    Widget body;
    if (c.state == Loading.loading) {
      body = const LoadingState();
    } else if (c.state == Loading.error) {
      body = ErrorState(message: c.error ?? 'Erro', onRetry: c.load);
    } else {
      final h = c.history;
      final summaries = (h?.summaries ?? []).where((s) => s.hasContent).toList();
      final requests = h?.examRequests ?? [];

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumos de consulta
          const _SectionLabel('RESUMOS DE CONSULTA'),
          if (summaries.isEmpty)
            const _EmptyNote('Nenhum resumo de consulta registrado.')
          else
            for (final s in summaries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SummaryCard(summary: s, history: h!, access: access),
              ),
          const SizedBox(height: 22),
          // Pedidos de exame
          const _SectionLabel('PEDIDOS DE EXAME'),
          if (requests.isEmpty)
            const _EmptyNote('Nenhum pedido de exame registrado.')
          else
            for (final r in requests)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ExamRequestCard(item: r, access: access),
              ),
        ],
      );
    }

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: c.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [body],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.history, required this.access});
  final ConsultationSummary summary;
  final ClinicalHistory history;
  final AccessController access;

  @override
  Widget build(BuildContext context) {
    Appointment? appt;
    for (final a in history.appointments) {
      if (a.id == summary.appointmentId) {
        appt = a;
        break;
      }
    }
    final doctor = access.doctorNameById(appt?.doctorId) ?? 'Médico(a)';
    final when = appt != null ? friendlyDate(appt.start) : '';
    final preview = (summary.assessment ?? summary.plan ?? summary.subjective ?? '').trim();

    return GestureDetector(
      onTap: appt == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ConsultaDetailScreen(appointment: appt!, summary: summary, doctorName: doctor),
              )),
      child: AccessCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.tealTint, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.notes_outlined, color: AppColors.tealDark, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doctor,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                  if (when.isNotEmpty)
                    Text(when, style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textSecondary)),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(preview,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 12.5, height: 1.4, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ExamRequestCard extends StatelessWidget {
  const _ExamRequestCard({required this.item, required this.access});
  final ExamRequestItem item;
  final AccessController access;

  @override
  Widget build(BuildContext context) {
    final by = item.externalDoctorName ?? access.doctorNameById(item.doctorId) ?? 'Profissional';
    return AccessCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.section, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.assignment_outlined, color: AppColors.brandDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.examType,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                Text('Solicitado por $by',
                    style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1, color: AppColors.textSecondary)),
      );
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.section,
        borderRadius: BorderRadius.circular(AppTheme.radiusInner),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
    );
  }
}
