import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class TournamentCalendarPrinting {
  static Future<void> printCalendar(
      List<String> timeSlots,
      List<String> sports,
      Map<String, Map<String, List<Map<String, dynamic>>>> calendarMap,
      DateTime selectedDate) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');

    // Calculate optimal font sizes based on number of columns
    final baseFontSize = sports.length > 8 ? 5.0 : 6.0;
    final timeColumnFontSize = sports.length > 8 ? 4.0 : 5.0;
    final eventFontSize = sports.length > 12 ? 4.0 : 5.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(10),
        maxPages: 100,
        build: (pw.Context context) {
          // If there are too many sports, split them into multiple pages
          if (sports.length > 10) {
            return _buildMultiPageCalendar(
                timeSlots, sports, calendarMap, selectedDate, dateFormat,
                baseFontSize: baseFontSize,
                timeColumnFontSize: timeColumnFontSize,
                eventFontSize: eventFontSize);
          } else {
            return [
              _buildCalendarTable(
                  timeSlots, sports, calendarMap, selectedDate, dateFormat,
                  baseFontSize: baseFontSize,
                  timeColumnFontSize: timeColumnFontSize,
                  eventFontSize: eventFontSize),
            ];
          }
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static List<pw.Widget> _buildMultiPageCalendar(
      List<String> timeSlots,
      List<String> sports,
      Map<String, Map<String, List<Map<String, dynamic>>>> calendarMap,
      DateTime selectedDate,
      DateFormat dateFormat,
      {required double baseFontSize,
      required double timeColumnFontSize,
      required double eventFontSize}) {
    final List<pw.Widget> pages = [];
    const int maxSportsPerPage = 8; // Adjust based on content density

    // Split sports into chunks for multiple pages
    for (int i = 0; i < sports.length; i += maxSportsPerPage) {
      final end = (i + maxSportsPerPage) < sports.length
          ? i + maxSportsPerPage
          : sports.length;
      final sportsSubset = sports.sublist(i, end);

      pages.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Tournament Calendar - ${dateFormat.format(selectedDate)}',
              style: pw.TextStyle(
                fontSize: baseFontSize + 2,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              // ignore: unnecessary_brace_in_string_interps
              'Sports ${i + 1}-${end} of ${sports.length}',
              style: pw.TextStyle(
                fontSize: baseFontSize,
                fontWeight: pw.FontWeight.normal,
              ),
            ),
            pw.SizedBox(height: 10),
            _buildCalendarTable(
                timeSlots, sportsSubset, calendarMap, selectedDate, dateFormat,
                baseFontSize: baseFontSize,
                timeColumnFontSize: timeColumnFontSize,
                eventFontSize: eventFontSize,
                isPartial: true),
          ],
        ),
      );
    }

    return pages;
  }

  static pw.Widget _buildCalendarTable(
      List<String> timeSlots,
      List<String> sports,
      Map<String, Map<String, List<Map<String, dynamic>>>> calendarMap,
      DateTime selectedDate,
      DateFormat dateFormat,
      {required double baseFontSize,
      required double timeColumnFontSize,
      required double eventFontSize,
      bool isPartial = false}) {
    // Calculate column widths
    final List<pw.TableColumnWidth> columnWidths = [
      const pw.FixedColumnWidth(40), // Time column width
      ...List.generate(sports.length, (index) => const pw.FlexColumnWidth(1)),
    ];

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        for (int i = 0; i < columnWidths.length; i++) i: columnWidths[i]
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'Time',
                style: pw.TextStyle(
                  fontSize: timeColumnFontSize + 1,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            ...sports.map((sport) => pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    sport.length > 15 ? '${sport.substring(0, 15)}...' : sport,
                    style: pw.TextStyle(
                      fontSize: baseFontSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                    maxLines: 2,
                  ),
                )),
          ],
        ),
        // Data rows
        ...timeSlots.map((timeSlot) {
          return pw.TableRow(
            children: [
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  timeSlot,
                  style: pw.TextStyle(
                    fontSize: timeColumnFontSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              ...sports.map((sport) {
                final events = calendarMap[timeSlot]?[sport] ?? [];
                if (events.isEmpty) {
                  return pw.Container(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text(''),
                  );
                }

                final eventTexts = events.map((event) {
                  final teams = event['teams'] as List<dynamic>? ?? [];
                  final tournamentName =
                      event['tournamentName'] as String? ?? 'Unknown';
                  final sportName = event['sportName'] as String? ?? 'Unknown';
                  final categoryName =
                      event['categoryName'] as String? ?? 'Unknown';
                  final venue = event['venue'] as String? ?? '';
                  final gender = event['gender'] as String? ?? '';

                  final teamsText = teams.length >= 2
                      ? '${teams[0]} vs ${teams[1]}'
                      : teams.isNotEmpty
                          ? teams[0]
                          : 'Unknown';

                  // Create concise event text
                  final textParts = [
                    tournamentName.length > 20
                        ? '${tournamentName.substring(0, 20)}...'
                        : tournamentName,
                    '$sportName ($categoryName)',
                    teamsText
                  ];

                  if (venue.isNotEmpty) {
                    textParts.add(
                        'Venue: ${venue.length > 15 ? '${venue.substring(0, 15)}...' : venue}');
                  }
                  if (gender.isNotEmpty) {
                    textParts.add('Gender: $gender');
                  }

                  return textParts.join('\n');
                }).join('\n\n');

                return pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Text(
                    eventTexts,
                    style: pw.TextStyle(
                      fontSize: eventFontSize,
                    ),
                    maxLines: 10, // Limit number of lines
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }
}
