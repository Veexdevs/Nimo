import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme.dart';

const _meses = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

/// Seletor de data com visual do Nimo (rodinhas dia / mês / ano)
Future<DateTime?> showNimoDatePicker(
  BuildContext context, {
  DateTime? initial,
  String title = 'Data de nascimento',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: const Color(0xFF101014),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _NimoDateSheet(initial: initial, title: title),
  );
}

class _NimoDateSheet extends StatefulWidget {
  final DateTime? initial;
  final String title;
  const _NimoDateSheet({this.initial, required this.title});

  @override
  State<_NimoDateSheet> createState() => _NimoDateSheetState();
}

class _NimoDateSheetState extends State<_NimoDateSheet> {
  late int _day;
  late int _month;
  late int _year;

  late final int _maxYear = DateTime.now().year;
  static const int _minYear = 1920;

  late final FixedExtentScrollController _dayCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _yearCtrl;

  @override
  void initState() {
    super.initState();
    final init = widget.initial ??
        DateTime(DateTime.now().year - 18, 1, 1);
    _day = init.day;
    _month = init.month;
    _year = init.year.clamp(_minYear, _maxYear);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _yearCtrl =
        FixedExtentScrollController(initialItem: _maxYear - _year);
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  void _fixDay() {
    final max = _daysInMonth(_year, _month);
    if (_day > max) {
      _day = max;
      _dayCtrl.jumpToItem(_day - 1);
    }
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int index) label,
    required void Function(int index) onChanged,
    double width = 90,
  }) {
    return SizedBox(
      width: width,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 44,
        perspective: 0.004,
        diameterRatio: 1.6,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (i) => setState(() => onChanged(i)),
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (_, i) => Center(
            child: Text(
              label(i),
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: NimoColors.textNormal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayCount = _daysInMonth(_year, _month);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A30),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Gire as rodinhas para escolher',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: NimoColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 196,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // faixa de seleção
                Container(
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 26),
                  decoration: BoxDecoration(
                    color: NimoColors.blue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: NimoColors.blue.withOpacity(0.4)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _wheel(
                      controller: _dayCtrl,
                      count: dayCount,
                      label: (i) => (i + 1).toString().padLeft(2, '0'),
                      onChanged: (i) => _day = i + 1,
                      width: 70,
                    ),
                    _wheel(
                      controller: _monthCtrl,
                      count: 12,
                      label: (i) => _meses[i],
                      onChanged: (i) {
                        _month = i + 1;
                        _fixDay();
                      },
                      width: 140,
                    ),
                    _wheel(
                      controller: _yearCtrl,
                      count: _maxYear - _minYear + 1,
                      label: (i) => (_maxYear - i).toString(),
                      onChanged: (i) {
                        _year = _maxYear - i;
                        _fixDay();
                      },
                      width: 84,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFF26262B), width: 1.4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context)
                        .pop(DateTime(_year, _month, _day)),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: NimoColors.blue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Confirmar',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
