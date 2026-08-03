import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/turf/domain/turf_models.dart';

void main() {
  group('Turf Model Tests', () {
    test('City.fromJson parses correctly', () {
      final json = {
        'id': 'city-1',
        'name': 'Bangalore',
        'state': 'Karnataka',
        'isActive': true,
      };

      final city = City.fromJson(json);

      expect(city.id, 'city-1');
      expect(city.name, 'Bangalore');
      expect(city.state, 'Karnataka');
      expect(city.isActive, true);
    });

    test('Turf.fromJson parses nested lists and properties correctly', () {
      final json = {
        'id': 'turf-123',
        'ownerId': 'owner-456',
        'name': 'Arena Football Club',
        'description': 'Superb turf',
        'address': 'Koramangala, Bangalore',
        'cityId': 'city-1',
        'basePricePerHour': 1500.0,
        'status': 'APPROVED',
        'openingTime': '06:00',
        'closingTime': '23:00',
        'slotDurationMinutes': 60,
        'city': {
          'id': 'city-1',
          'name': 'Bangalore',
          'state': 'Karnataka',
          'isActive': true,
        },
        'images': [
          {
            'id': 'img-1',
            'url': 'http://image.url',
            'publicId': 'pub-1',
            'createdAt': '2026-07-29T17:00:00Z',
          },
        ],
        'amenities': [
          {'id': 'am-1', 'name': 'Parking', 'iconUrl': 'parking_icon'},
        ],
        'courts': [
          {
            'id': 'court-1',
            'turfId': 'turf-123',
            'name': 'Court A',
            'type': '5-a-side',
            'pricePerHour': 1200.0,
            'isActive': true,
            'sports': [
              {'id': 'sport-1', 'name': 'Football', 'iconUrl': 'soccer_icon'},
            ],
          },
        ],
      };

      final turf = Turf.fromJson(json);

      expect(turf.id, 'turf-123');
      expect(turf.ownerId, 'owner-456');
      expect(turf.name, 'Arena Football Club');
      expect(turf.basePricePerHour, 1500.0);
      expect(turf.city?.name, 'Bangalore');

      expect(turf.images.length, 1);
      expect(turf.images.first.url, 'http://image.url');

      expect(turf.amenities.length, 1);
      expect(turf.amenities.first.name, 'Parking');

      expect(turf.courts.length, 1);
      expect(turf.courts.first.name, 'Court A');
      expect(turf.courts.first.sports.first.name, 'Football');
    });
  });
}
