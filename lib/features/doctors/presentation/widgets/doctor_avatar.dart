import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../access/presentation/widgets/access_common.dart';
import '../../data/doctor_models.dart';
import '../../data/doctors_repository.dart';

class DoctorAvatar extends StatefulWidget {
  const DoctorAvatar({
    super.key,
    required this.doctor,
    required this.repository,
    this.size = 52,
  });

  final DoctorListItem doctor;
  final DoctorsRepository repository;
  final double size;

  static final Map<String, Uint8List> _cache = {};

  @override
  State<DoctorAvatar> createState() => _DoctorAvatarState();
}

class _DoctorAvatarState extends State<DoctorAvatar> {
  Uint8List? _bytes;

  String get _cacheKey =>
      '${widget.doctor.id}:${widget.doctor.photoUpdatedAt?.millisecondsSinceEpoch ?? 0}';

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant DoctorAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doctor.id != widget.doctor.id ||
        oldWidget.doctor.photoUpdatedAt != widget.doctor.photoUpdatedAt) {
      _bytes = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    if (!widget.doctor.hasPhoto) return;

    final cached = DoctorAvatar._cache[_cacheKey];
    if (cached != null) {
      setState(() => _bytes = cached);
      return;
    }

    try {
      final bytes = await widget.repository.getPhoto(widget.doctor.id);
      if (!mounted || bytes.isEmpty) return;
      DoctorAvatar._cache[_cacheKey] = bytes;
      setState(() => _bytes = bytes);
    } catch (_) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return InitialsAvatar(initials: widget.doctor.initials, size: widget.size);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.size * 0.38),
      child: Image.memory(
        bytes,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}
