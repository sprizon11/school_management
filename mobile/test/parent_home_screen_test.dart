import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_school/core/network/api_client.dart';
import 'package:smart_school/features/parent/presentation/screens/parent_home_screen.dart';

/// Serves a canned /parent/home payload so the screen can be laid out without
/// a backend.
class _StubAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '''
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
            "marks": 80, "maxMarks": 100, "grade": "A",
            "remarks": null, "percent": 80
          }]
        },
        "homework": [{
          "id": "h1", "title": "Read chapter 4",
          "description": "Pages 40-52", "dueDate": "2026-07-25T00:00:00.000Z"
        }],
        "dueThisWeek": 1,
        "announcement": {
          "id": "a1", "title": "PTM this Saturday", "body": "Main hall",
          "eventDate": "2026-07-25T00:00:00.000Z",
          "createdAt": "2026-07-19T00:00:00.000Z"
        }
      }
      ''',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  testWidgets('parent home lays out every section without overflow', (
    tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://stub'))
      ..httpClientAdapter = _StubAdapter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const MaterialApp(home: Scaffold(body: ParentHomeScreen())),
      ),
    );
    await tester.pumpAndSettle();

    // A layout exception (e.g. an unbounded-height Row) surfaces here.
    expect(tester.takeException(), isNull);

    // Sections below the stats row are the ones that disappeared when the
    // stats Row tried to stretch to an infinite height.
    expect(find.text('Arjun Menon'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Absences'), findsOneWidget);
    expect(find.text('PTM this Saturday'), findsOneWidget);
    expect(find.text('Recent Marks'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Upcoming Homework'), findsOneWidget);
    expect(find.text('Read chapter 4'), findsOneWidget);
  });
}
