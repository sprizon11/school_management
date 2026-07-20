import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_school/core/network/api_client.dart';
import 'package:smart_school/features/parent/presentation/screens/parent_home_screen.dart';
import 'package:smart_school/features/parent/presentation/screens/parent_marks_screen.dart';
import 'package:smart_school/features/parent/presentation/screens/parent_fees_screen.dart';

/// Routes canned JSON by request path so each parent screen can be laid out
/// without a backend.
class _StubAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final body = switch (path) {
      '/parent/marks' => _marksJson,
      '/parent/fees' => _feesJson,
      _ => _homeJson,
    };
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

const _homeJson = '''
{
  "child": {
    "id": "s1", "fullName": "Arjun Menon", "studentCode": "STU1",
    "rollNumber": 2, "avatarUrl": null, "className": "Class 1-A",
    "classTeacher": "Anita Rao", "schoolName": "Greenfield Public School"
  },
  "attendance": {
    "present": 8, "absent": 1, "leave": 0, "marked": 9,
    "absentThisMonth": 1, "percent": 89
  },
  "marks": {
    "average": 80, "count": 1,
    "recent": [{
      "id": "m1", "subject": "English", "termLabel": "Unit Test 1",
      "marks": 80, "maxMarks": 100, "grade": "A", "remarks": null, "percent": 80
    }]
  },
  "homework": [],
  "upcomingTests": [{
    "id": "t1", "title": "Maths Unit Test 2",
    "body": "Chapters 4-6", "eventDate": "2030-07-25T00:00:00.000Z"
  }],
  "dueThisWeek": 1,
  "announcement": {
    "id": "a1", "title": "PTM this Saturday", "body": "Main hall",
    "eventDate": "2026-07-25T00:00:00.000Z", "createdAt": "2026-07-19T00:00:00.000Z"
  }
}
''';

const _marksJson = '''
[
  {"id": "m1", "subject": "English", "termLabel": "Unit Test 1",
   "marks": 80, "maxMarks": 100, "grade": "A", "remarks": "Good work", "percent": 80},
  {"id": "m2", "subject": "Maths", "termLabel": "Unit Test 1",
   "marks": 45, "maxMarks": 100, "grade": "C", "remarks": null, "percent": 45}
]
''';

const _feesJson = '''
{
  "summary": {"total": 48000, "paid": 24000, "pending": 12000, "upcoming": 12000, "due": 24000},
  "installments": [
    {"id": "i1", "label": "Term 1", "amount": 12000, "dueDate": "2025-06-15T00:00:00.000Z",
     "status": "PAID", "term": "Annual", "paidAt": "2025-06-15T00:00:00.000Z"},
    {"id": "i3", "label": "Term 3", "amount": 12000, "dueDate": "2026-08-15T00:00:00.000Z",
     "status": "PENDING", "term": "Annual", "paidAt": null}
  ]
}
''';

Widget _wrap(Widget child, Dio dio) => ProviderScope(
  overrides: [dioProvider.overrideWithValue(dio)],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  Dio stubbedDio() =>
      Dio(BaseOptions(baseUrl: 'http://stub'))..httpClientAdapter = _StubAdapter();

  testWidgets('parent home lays out every section without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ParentHomeScreen(), stubbedDio()));
    await tester.pumpAndSettle();

    // A layout exception (e.g. an unbounded-height Row) surfaces here.
    expect(tester.takeException(), isNull);

    expect(find.text('Arjun Menon'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Absences'), findsOneWidget);
    // Avg Marks tile was removed; it must not reappear.
    expect(find.text('Avg Marks'), findsNothing);
    expect(find.text('Recent Marks'), findsOneWidget);
    expect(find.text('Upcoming Tests'), findsOneWidget);
    expect(find.text('Maths Unit Test 2'), findsOneWidget);
  });

  testWidgets('parent marks screen groups by term', (tester) async {
    await tester.pumpWidget(_wrap(const ParentMarksScreen(), stubbedDio()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Marks'), findsOneWidget);
    expect(find.text('Unit Test 1'), findsOneWidget); // term header
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Maths'), findsOneWidget);
    expect(find.text('80 / 100'), findsOneWidget);
  });

  testWidgets('parent fees screen shows summary and installments', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ParentFeesScreen(), stubbedDio()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Fees'), findsOneWidget);
    expect(find.text('Balance Due'), findsOneWidget);
    expect(find.text('Payment Schedule'), findsOneWidget);
    expect(find.text('Term 1'), findsOneWidget);
    expect(find.text('Term 3'), findsOneWidget);
    expect(find.text('Paid'), findsWidgets);
    expect(find.text('Due'), findsWidgets);
  });
}
