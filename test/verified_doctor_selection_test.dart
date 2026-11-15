import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oralyn/services/doctor_case_service.dart';
import 'package:oralyn/views/screens/doctors/verified_doctor_screens.dart';

void main() {
  testWidgets('review picker returns a verified Doctor from the live service',
      (tester) async {
    final service = DoctorCaseService(
      client: MockClient((request) async {
        expect(request.url.path, '/doctors');
        return http.Response(
          '{"items":[{"directory_id":"40000000-0000-4000-8000-000000000001",'
          '"display_name":"Synthetic Verified Doctor",'
          '"specialization":"Oral medicine","workplace":"Test clinic"}]}',
          200,
        );
      }),
      predictionEndpoint: Uri.parse('https://example.test/predict'),
      tokenProvider: () async => 'synthetic-session',
    );
    Map<String, dynamic>? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                  onPressed: () async {
                    chosen = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => Scaffold(
                                body: VerifiedDoctorDirectory(
                                    selecting: true, caseService: service),
                              )),
                    );
                  },
                  child: const Text('Choose'),
                )),
      ),
    ));
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic Verified Doctor'), findsOneWidget);
    await tester.tap(find.text('Synthetic Verified Doctor'));
    await tester.pumpAndSettle();
    expect(chosen?['directory_id'], '40000000-0000-4000-8000-000000000001');
    service.close();
  });

  testWidgets('service failure never displays dummy Doctors', (tester) async {
    final service = DoctorCaseService(
      client: MockClient((_) async => http.Response('{}', 503)),
      predictionEndpoint: Uri.parse('https://example.test/predict'),
      tokenProvider: () async => 'synthetic-session',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: VerifiedDoctorDirectory(selecting: true, caseService: service)),
    ));
    await tester.pumpAndSettle();
    expect(
        find.text('Verified Doctor profiles are unavailable.'), findsOneWidget);
    expect(find.text('Synthetic Verified Doctor'), findsNothing);
    service.close();
  });
}
