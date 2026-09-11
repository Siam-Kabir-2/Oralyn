import '../../models/clinic.dart';
import '../../models/doctor.dart';
import '../../models/screening_result.dart';

abstract final class MockData {
  // Change this from 0–3 to demo a different deterministic screening result.
  static const activeScenarioIndex = 2;

  static final results = <ScreeningResult>[
    ScreeningResult(
      id: 'S-105',
      date: DateTime(2026, 9, 24, 10, 20),
      category: LesionCategory.healthy,
      risk: RiskLevel.lowConcern,
      confidence: .91,
      status: 'Low Concern',
      summary:
          'No concerning visible pattern was highlighted in this screening.',
      recommendation:
          'Continue routine oral care and monitor for persistent changes.',
    ),
    ScreeningResult(
      id: 'S-104',
      date: DateTime(2026, 8, 12, 16, 5),
      category: LesionCategory.benign,
      risk: RiskLevel.professionalReview,
      confidence: .77,
      status: 'Professional Review Recommended',
      summary:
          'A visible change may benefit from a routine professional review.',
      recommendation:
          'Arrange a dental examination if the area persists or changes.',
    ),
    ScreeningResult(
      id: 'S-103',
      date: DateTime(2026, 7, 2, 9, 40),
      category: LesionCategory.opmd,
      risk: RiskLevel.professionalReview,
      confidence: .82,
      status: 'Professional Review Recommended',
      summary:
          'The image contains visible features that should be reviewed by a dental professional.',
      recommendation: 'Arrange a professional oral examination.',
    ),
    ScreeningResult(
      id: 'S-102',
      date: DateTime(2026, 5, 18, 14, 15),
      category: LesionCategory.oralCancer,
      risk: RiskLevel.promptSpecialistReview,
      confidence: .86,
      status: 'Prompt Specialist Review',
      summary:
          'The visible pattern warrants timely assessment by an oral health specialist.',
      recommendation:
          'Consult an oral medicine or oral and maxillofacial specialist promptly.',
    ),
    ScreeningResult(
      id: 'S-101',
      date: DateTime(2026, 3, 8, 11, 0),
      category: LesionCategory.benign,
      risk: RiskLevel.lowConcern,
      confidence: .74,
      status: 'Low Concern',
      summary:
          'The visible pattern appears lower concern in this preliminary screening.',
      recommendation:
          'Monitor the area and seek care if it lasts longer than two weeks.',
    ),
  ];

  static const doctors = <Doctor>[
    Doctor(
      id: 'd1',
      name: 'Dr. Sarah Ahmed',
      specialty: 'Oral & Maxillofacial Surgeon',
      facility: 'City Dental Hospital',
      address: '18 Lakeview Avenue, Dhanmondi',
      distanceKm: 1.8,
      availability: 'Available tomorrow',
      qualifications: 'BDS, FCPS (Oral & Maxillofacial Surgery)',
      phone: '+880 1700 100 201',
      bio:
          'Dr. Ahmed focuses on oral lesion assessment and patient-centered surgical care, with over twelve years of clinical experience.',
    ),
    Doctor(
      id: 'd2',
      name: 'Dr. Rafid Hasan',
      specialty: 'Oral Medicine Specialist',
      facility: 'Northpoint Oral Care',
      address: '42 Green Road, Dhaka',
      distanceKm: 2.3,
      availability: 'Next slot 5:30 PM',
      qualifications: 'BDS, MSc Oral Medicine',
      phone: '+880 1700 100 202',
      bio:
          'Dr. Hasan provides comprehensive evaluation of persistent oral conditions and mucosal changes.',
    ),
    Doctor(
      id: 'd3',
      name: 'Dr. Nabila Karim',
      specialty: 'Dentist',
      facility: 'Harbor Dental Studio',
      address: '9 Satmasjid Road, Dhaka',
      distanceKm: 3.1,
      availability: 'Available today',
      qualifications: 'BDS, PGT',
      phone: '+880 1700 100 203',
      bio:
          'Dr. Karim practices preventive dentistry and early referral for complex oral health concerns.',
    ),
    Doctor(
      id: 'd4',
      name: 'Dr. Imran Chowdhury',
      specialty: 'Oral & Maxillofacial Surgeon',
      facility: 'Metropolitan Medical Centre',
      address: '71 Panthapath, Dhaka',
      distanceKm: 4.0,
      availability: 'Available Thursday',
      qualifications: 'BDS, MS',
      phone: '+880 1700 100 204',
      bio:
          'Dr. Chowdhury specializes in diagnostic assessment and maxillofacial procedures.',
    ),
    Doctor(
      id: 'd5',
      name: 'Dr. Anika Rahman',
      specialty: 'Oral Medicine Specialist',
      facility: 'Wellbeing Hospital',
      address: '25 Mirpur Road, Dhaka',
      distanceKm: 5.4,
      availability: 'Next slot Friday',
      qualifications: 'BDS, MPhil Oral Pathology',
      phone: '+880 1700 100 205',
      bio:
          'Dr. Rahman has a special interest in oral mucosal disease and coordinated referral care.',
    ),
    Doctor(
      id: 'd6',
      name: 'Dr. Tahmid Noor',
      specialty: 'Dentist',
      facility: 'Crescent Dental Care',
      address: '16 New Eskaton Road, Dhaka',
      distanceKm: 6.2,
      availability: 'Available Saturday',
      qualifications: 'BDS',
      phone: '+880 1700 100 206',
      bio:
          'Dr. Noor delivers calm, evidence-informed general dental care for adults and families.',
    ),
  ];

  static const clinics = <Clinic>[
    Clinic(
      name: 'City Dental Hospital',
      type: 'Dental hospital',
      distanceKm: 1.8,
      address: '18 Lakeview Avenue',
    ),
    Clinic(
      name: 'Northpoint Oral Care',
      type: 'Specialist clinic',
      distanceKm: 2.3,
      address: '42 Green Road',
    ),
    Clinic(
      name: 'Metropolitan Medical Centre',
      type: 'Hospital',
      distanceKm: 4.0,
      address: '71 Panthapath',
    ),
    Clinic(
      name: 'Wellbeing Hospital',
      type: 'Hospital',
      distanceKm: 5.4,
      address: '25 Mirpur Road',
    ),
    Clinic(
      name: 'Crescent Dental Care',
      type: 'Dental clinic',
      distanceKm: 6.2,
      address: '16 New Eskaton Road',
    ),
  ];
}
