import 'package:flutter_test/flutter_test.dart';
import 'package:chifa/services/db/models/soins_service.dart';
import 'package:chifa/services/db/models/payment_service.dart';
import 'package:chifa/services/db/models/service.dart';

void main() {
  group('SoinsService Model Tests', () {
    test('default price and doctor commission should be 0.0', () {
      const soin = SoinsService(nom: 'Injection IM');
      expect(soin.price, 0.0);
      expect(soin.doctorCommission, 0.0);
      expect(soin.nom, 'Injection IM');
    });

    test('toMap and fromMap should serialize price and doctor_commission', () {
      const soin = SoinsService(
        id: 10,
        uuid: 'test-uuid-1',
        nom: 'Aérosol',
        price: 500.0,
        doctorCommission: 100.0,
      );

      final map = soin.toMap();
      expect(map['id'], 10);
      expect(map['uuid'], 'test-uuid-1');
      expect(map['nom'], 'Aérosol');
      expect(map['price'], 500.0);
      expect(map['doctor_commission'], 100.0);

      final reconstructed = SoinsService.fromMap(map);
      expect(reconstructed.id, 10);
      expect(reconstructed.nom, 'Aérosol');
      expect(reconstructed.price, 500.0);
      expect(reconstructed.doctorCommission, 100.0);
    });

    test('fromMap should handle legacy prix key if price is not present', () {
      final legacyMap = {
        'id': 12,
        'nom': 'Pansement simple',
        'prix': '350.00',
        'doctor_commission': 50.0,
      };

      final soin = SoinsService.fromMap(legacyMap);
      expect(soin.id, 12);
      expect(soin.nom, 'Pansement simple');
      expect(soin.price, 350.0);
      expect(soin.doctorCommission, 50.0);
    });

    test('copyWith updates fields properly', () {
      const original = SoinsService(
        id: 1,
        nom: 'Soin Test',
        price: 200.0,
        doctorCommission: 50.0,
      );

      final modified = original.copyWith(
        price: 300.0,
        doctorCommission: 80.0,
      );

      expect(modified.id, 1);
      expect(modified.nom, 'Soin Test');
      expect(modified.price, 300.0);
      expect(modified.doctorCommission, 80.0);
    });
  });

  group('PaymentService Model Tests', () {
    test('default serviceType should be act', () {
      const ps = PaymentService(
        serviceName: 'Consultation',
        servicePrice: 1500.0,
        doctorCommission: 600.0,
      );
      expect(ps.serviceType, 'act');
    });

    test('supports soin serviceType and serializes correctly', () {
      const ps = PaymentService(
        id: 42,
        paymentId: 100,
        serviceId: 5,
        serviceName: 'Injection Spasfon',
        servicePrice: 300.0,
        doctorCommission: 50.0,
        serviceType: 'soin',
      );

      final map = ps.toMap();
      expect(map['service_type'], 'soin');
      expect(map['service_price'], 300.0);
      expect(map['doctor_commission'], 50.0);

      final reconstructed = PaymentService.fromMap(map);
      expect(reconstructed.serviceType, 'soin');
      expect(reconstructed.servicePrice, 300.0);
      expect(reconstructed.doctorCommission, 50.0);
    });
  });
}
