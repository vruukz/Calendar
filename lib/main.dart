import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

Future<void> initNotifications() async {}
Future<void> scheduleNotification(CalEvent event) async {}
Future<void> cancelNotification(String id) async {}

// ── MODEL ─────────────────────────────────────────────────
class CalEvent {
  String id;
  String title;
  String description;
  DateTime dateTime;
  int? reminder;
  String color;

  CalEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.dateTime,
    this.reminder,
    this.color = 'green',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'dateTime': dateTime.toIso8601String(),
    'reminder': reminder,
    'color': color,
  };

  factory CalEvent.fromJson(Map<String, dynamic> j) => CalEvent(
    id: j['id'],
    title: j['title'],
    description: j['description'] ?? '',
    dateTime: DateTime.parse(j['dateTime']),
    reminder: j['reminder'],
    color: j['color'] ?? 'green',
  );
}

// ── THEME ─────────────────────────────────────────────────
const kBg = Color(0xFF0D0D0D);
const kSurface = Color(0xFF161616);
const kBorder = Color(0xFF252525);
const kText = Color(0xFFE8E2D9);
const kMuted = Color(0xFF666666);
const kAccent = Color(0xFFC8F060);
const kAccent2 = Color(0xFFF0A860);

const eventColors = {
  'green': Color(0xFFC8F060),
  'orange': Color(0xFFF0A860),
  'blue': Color(0xFF60C8F0),
  'red': Color(0xFFF06060),
  'purple': Color(0xFFA860F0),
};

// ── APP ───────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  runApp(const CalendarApp());
}

class CalendarApp extends StatelessWidget {
  const CalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(primary: kAccent, surface: kSurface),
        fontFamily: 'monospace',
      ),
      home: const CalendarHome(),
    );
  }
}

// ── HOME ──────────────────────────────────────────────────
class CalendarHome extends StatefulWidget {
  const CalendarHome({super.key});
  @override
  State<CalendarHome> createState() => _CalendarHomeState();
}

class _CalendarHomeState extends State<CalendarHome> {
  DateTime focusedDay = DateTime.now();
  DateTime selectedDay = DateTime.now();
  Map<String, List<CalEvent>> events = {};
  CalendarFormat calFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('events') ?? [];
    setState(() {
      events = {};
      for (final s in raw) {
        final e = CalEvent.fromJson(json.decode(s));
        final key = _dayKey(e.dateTime);
        events[key] = [...(events[key] ?? []), e];
      }
    });
  }

  Future<void> saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final all = events.values.expand((e) => e).toList();
    await prefs.setStringList('events', all.map((e) => json.encode(e.toJson())).toList());
  }

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
  List<CalEvent> eventsForDay(DateTime day) => events[_dayKey(day)] ?? [];

  void addOrEditEvent(CalEvent? existing) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventEditPage(event: existing, selectedDay: selectedDay)),
    );
    if (result != null) {
      setState(() {
        if (existing != null) {
          final oldKey = _dayKey(existing.dateTime);
          events[oldKey]?.removeWhere((e) => e.id == existing.id);
          cancelNotification(existing.id);
        }
        final key = _dayKey(result.dateTime);
        events[key] = [...(events[key] ?? []), result];
      });
      await saveEvents();
      await scheduleNotification(result);
    }
  }

  void deleteEvent(CalEvent event) {
    setState(() {
      final key = _dayKey(event.dateTime);
      events[key]?.removeWhere((e) => e.id == event.id);
    });
    cancelNotification(event.id);
    saveEvents();
  }

  String get _formatLabel {
    switch (calFormat) {
      case CalendarFormat.month: return 'MONTH';
      case CalendarFormat.twoWeeks: return '2 WEEKS';
      case CalendarFormat.week: return 'WEEK';
    }
  }

  void _cycleFormat() {
    setState(() {
      switch (calFormat) {
        case CalendarFormat.month: calFormat = CalendarFormat.twoWeeks; break;
        case CalendarFormat.twoWeeks: calFormat = CalendarFormat.week; break;
        case CalendarFormat.week: calFormat = CalendarFormat.month; break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dayEvents = eventsForDay(selectedDay);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  const Text('CALENDAR', style: TextStyle(fontSize: 11, letterSpacing: 6, color: kAccent)),
                  const Spacer(),
                  Text(DateFormat('MMMM yyyy').format(focusedDay).toUpperCase(),
                    style: const TextStyle(fontSize: 10, color: kMuted, letterSpacing: 2)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Calendar
            TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: focusedDay,
              selectedDayPredicate: (d) => isSameDay(d, selectedDay),
              calendarFormat: calFormat,
              onFormatChanged: (f) => setState(() => calFormat = f),
              availableCalendarFormats: const {
                CalendarFormat.month: 'MONTH',
                CalendarFormat.twoWeeks: '2 WEEKS',
                CalendarFormat.week: 'WEEK',
              },
              eventLoader: eventsForDay,
              onDaySelected: (selected, focused) {
                setState(() {
                  selectedDay = selected;
                  focusedDay = focused;
                });
              },
              onPageChanged: (focused) => setState(() => focusedDay = focused),
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
                defaultTextStyle: TextStyle(color: kText, fontSize: 13, fontFamily: 'monospace'),
                weekendTextStyle: TextStyle(color: kMuted, fontSize: 13, fontFamily: 'monospace'),
                selectedDecoration: BoxDecoration(color: kAccent, shape: BoxShape.circle),
                selectedTextStyle: TextStyle(color: kBg, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                todayDecoration: BoxDecoration(border: Border.fromBorderSide(BorderSide(color: kAccent)), shape: BoxShape.circle),
                todayTextStyle: TextStyle(color: kAccent, fontSize: 13, fontFamily: 'monospace'),
                markerDecoration: BoxDecoration(color: kAccent2, shape: BoxShape.circle),
                markersMaxCount: 3,
                cellMargin: EdgeInsets.all(4),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: false,
                leftChevronIcon: const Icon(Icons.chevron_left, color: kMuted, size: 20),
                rightChevronIcon: const Icon(Icons.chevron_right, color: kMuted, size: 20),
                titleTextStyle: const TextStyle(color: kText, fontSize: 13, fontFamily: 'monospace'),
                headerPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                rightChevronMargin: EdgeInsets.zero,
                leftChevronMargin: EdgeInsets.zero,
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: kMuted, fontSize: 11, fontFamily: 'monospace'),
                weekendStyle: TextStyle(color: kMuted, fontSize: 11, fontFamily: 'monospace'),
              ),
            ),

            // Custom format button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _cycleFormat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: kBorder),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_formatLabel, style: const TextStyle(fontSize: 10, color: kMuted, letterSpacing: 2)),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: kBorder, height: 1),
            const SizedBox(height: 8),

            // Selected day header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d').format(selectedDay).toUpperCase(),
                    style: const TextStyle(fontSize: 10, color: kMuted, letterSpacing: 2),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => addOrEditEvent(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: kAccent.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(4),
                        color: kAccent.withOpacity(0.05),
                      ),
                      child: const Text('+ EVENT', style: TextStyle(fontSize: 10, color: kAccent, letterSpacing: 2)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Events list
            Expanded(
              child: dayEvents.isEmpty
                ? const Center(child: Text('No events', style: TextStyle(color: kMuted, fontSize: 11, letterSpacing: 2)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: dayEvents.length,
                    itemBuilder: (_, i) => _buildEventCard(dayEvents[i]),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(CalEvent event) {
    final color = eventColors[event.color] ?? kAccent;
    return GestureDetector(
      onTap: () => addOrEditEvent(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: const TextStyle(fontSize: 13, color: kText, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 11, color: kMuted),
                      const SizedBox(width: 4),
                      Text(DateFormat('HH:mm').format(event.dateTime), style: const TextStyle(fontSize: 11, color: kMuted)),
                      if (event.reminder != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.notifications_outlined, size: 11, color: kMuted),
                        const SizedBox(width: 4),
                        Text('${event.reminder}m', style: const TextStyle(fontSize: 11, color: kMuted)),
                      ],
                    ],
                  ),
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(event.description, style: const TextStyle(fontSize: 11, color: kMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _confirmDelete(event),
              child: const Icon(Icons.delete_outline, size: 16, color: kMuted),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(CalEvent event) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Delete event?', style: TextStyle(color: kText, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: kMuted))),
          TextButton(onPressed: () { Navigator.pop(context); deleteEvent(event); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

// ── EVENT EDIT PAGE ───────────────────────────────────────
class EventEditPage extends StatefulWidget {
  final CalEvent? event;
  final DateTime selectedDay;
  const EventEditPage({super.key, this.event, required this.selectedDay});
  @override
  State<EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends State<EventEditPage> {
  late TextEditingController titleCtrl;
  late TextEditingController descCtrl;
  late DateTime eventDate;
  late TimeOfDay eventTime;
  int? reminderMinutes;
  late String selectedColor;

  final reminderOptions = [
    {'label': 'None', 'value': null},
    {'label': 'At time', 'value': 0},
    {'label': '5 min', 'value': 5},
    {'label': '15 min', 'value': 15},
    {'label': '30 min', 'value': 30},
    {'label': '1 hour', 'value': 60},
    {'label': '1 day', 'value': 1440},
  ];

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.event?.title ?? '');
    descCtrl = TextEditingController(text: widget.event?.description ?? '');
    eventDate = widget.event?.dateTime ?? widget.selectedDay;
    eventTime = TimeOfDay.fromDateTime(widget.event?.dateTime ?? DateTime.now());
    reminderMinutes = widget.event?.reminder;
    selectedColor = widget.event?.color ?? 'green';
  }

  CalEvent get result {
    final dt = DateTime(eventDate.year, eventDate.month, eventDate.day, eventTime.hour, eventTime.minute);
    return CalEvent(
      id: widget.event?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: titleCtrl.text,
      description: descCtrl.text,
      dateTime: dt,
      reminder: reminderMinutes,
      color: selectedColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: kMuted, size: 20),
                  ),
                  const SizedBox(width: 16),
                  const Text('EVENT', style: TextStyle(fontSize: 11, letterSpacing: 4, color: kAccent)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      if (titleCtrl.text.trim().isEmpty) return;
                      Navigator.pop(context, result);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(4)),
                      child: const Text('SAVE', style: TextStyle(fontSize: 10, color: kBg, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: kBorder, height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: kText, fontSize: 20, fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        hintText: 'Event title...',
                        hintStyle: TextStyle(color: kMuted),
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(color: kBorder),
                    const SizedBox(height: 16),

                    _sectionLabel('DATE'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: eventDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (_, child) => Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(primary: kAccent, surface: kSurface),
                            ),
                            child: child!,
                          ),
                        );
                        if (d != null) setState(() => eventDate = d);
                      },
                      child: _fieldBox(DateFormat('EEEE, MMMM d yyyy').format(eventDate)),
                    ),
                    const SizedBox(height: 16),

                    _sectionLabel('TIME'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: eventTime,
                          builder: (_, child) => Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(primary: kAccent, surface: kSurface),
                            ),
                            child: child!,
                          ),
                        );
                        if (t != null) setState(() => eventTime = t);
                      },
                      child: _fieldBox(eventTime.format(context)),
                    ),
                    const SizedBox(height: 16),

                    _sectionLabel('REMINDER'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: reminderOptions.map((r) {
                        final val = r['value'] as int?;
                        final selected = reminderMinutes == val;
                        return GestureDetector(
                          onTap: () => setState(() => reminderMinutes = val),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: selected ? kAccent : kBorder),
                              borderRadius: BorderRadius.circular(4),
                              color: selected ? kAccent.withOpacity(0.1) : kSurface,
                            ),
                            child: Text(
                              r['label'] as String,
                              style: TextStyle(fontSize: 11, color: selected ? kAccent : kMuted, letterSpacing: 1),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    _sectionLabel('COLOR'),
                    const SizedBox(height: 8),
                    Row(
                      children: eventColors.entries.map((e) {
                        final selected = selectedColor == e.key;
                        return GestureDetector(
                          onTap: () => setState(() => selectedColor = e.key),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: e.value,
                              shape: BoxShape.circle,
                              border: selected ? Border.all(color: kText, width: 2) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    _sectionLabel('NOTES'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kSurface,
                        border: Border.all(color: kBorder),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TextField(
                        controller: descCtrl,
                        style: const TextStyle(color: kText, fontSize: 13, height: 1.6),
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Add notes...',
                          hintStyle: TextStyle(color: kMuted),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(label, style: const TextStyle(fontSize: 9, color: kMuted, letterSpacing: 3));

  Widget _fieldBox(String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: kSurface,
      border: Border.all(color: kBorder),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(value, style: const TextStyle(fontSize: 13, color: kText)),
  );
}