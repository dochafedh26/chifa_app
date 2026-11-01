import 'package:flutter_test/flutter_test.dart';
import 'package:chifa/services/db/models/service.dart';
import 'package:chifa/services/db/models/soins_service.dart';
import 'package:chifa/services/db/models/payment_service.dart';

void main() {
  group('Payment Split Calculation Tests', () {
    final acts = [
      Service(serviceId: 1, serviceName: 'Consultation Générale', price: 1500.0, doctorCommission: 600.0),
      Service(serviceId: 2, serviceName: 'Lavage d\'oreille', price: 1000.0, doctorCommission: 400.0),
    ];

    final soins = [
      const SoinsService(id: 10, nom: 'Spasfon 40mg', price: 300.0, doctorCommission: 50.0),
      const SoinsService(id: 11, nom: 'Dexaméthasone', price: 400.0, doctorCommission: 70.0),
    ];

    test('calculates subtotals correctly', () {
      final actsSubtotal = acts.fold(0.0, (sum, s) => sum + s.price);
      final soinsSubtotal = soins.fold(0.0, (sum, s) => sum + s.price);

      expect(actsSubtotal, 2500.0);
      expect(soinsSubtotal, 700.0);
    });

    test('calculates combined total payment amount correctly', () {
      final actsSubtotal = acts.fold(0.0, (sum, s) => sum + s.price);
      final soinsSubtotal = soins.fold(0.0, (sum, s) => sum + s.price);
      final totalAmount = actsSubtotal + soinsSubtotal;

      expect(totalAmount, 3200.0);
    });

    test('calculates total doctor commission correctly across acts and soins', () {
      final actsCommission = acts.fold(0.0, (sum, s) => sum + s.doctorCommission);
      final soinsCommission = soins.fold(0.0, (sum, s) => sum + s.doctorCommission);
      final totalCommission = actsCommission + soinsCommission;

      expect(actsCommission, 1000.0);
      expect(soinsCommission, 120.0);
      expect(totalCommission, 1120.0);
    });

    test('calculates net clinic share correctly', () {
      final totalAmount = acts.fold(0.0, (sum, s) => sum + s.price) + soins.fold(0.0, (sum, s) => sum + s.price);
      final totalCommission = acts.fold(0.0, (sum, s) => sum + s.doctorCommission) + soins.fold(0.0, (sum, s) => sum + s.doctorCommission);
      final clinicNetShare = totalAmount - totalCommission;

      expect(clinicNetShare, 2080.0);
    });

    test('generates formatted services summary text with acts and soins', () {
      final actsNames = acts.map((s) => s.serviceName).join(', ');
      final soinsNames = soins.map((s) => s.nom).join(', ');

      String summary;
      if (actsNames.isNotEmpty && soinsNames.isNotEmpty) {
        summary = 'Actes: $actsNames | Soins: $soinsNames';
      } else if (actsNames.isNotEmpty) {
        summary = actsNames;
      } else {
        summary = soinsNames;
      }

      expect(
        summary,
        "Actes: Consultation Générale, Lavage d'oreille | Soins: Spasfon 40mg, Dexaméthasone",
      );
    });

    test('creates itemized PaymentServices with appropriate serviceType', () {
      final paymentServices = [
        ...acts.map((a) => PaymentService(
          serviceId: a.serviceId,
          serviceName: a.serviceName,
          servicePrice: a.price,
          doctorCommission: a.doctorCommission,
          serviceType: 'act',
        )),
        ...soins.map((s) => PaymentService(
          serviceId: s.id,
          serviceName: s.nom,
          servicePrice: s.price,
          doctorCommission: s.doctorCommission,
          serviceType: 'soin',
        )),
      ];

      expect(paymentServices.length, 4);
      expect(paymentServices[0].serviceType, 'act');
      expect(paymentServices[1].serviceType, 'act');
      expect(paymentServices[2].serviceType, 'soin');
      expect(paymentServices[3].serviceType, 'soin');
    });

    group('Discount (Remise) Calculations', () {
      final subtotal = 3200.0;

      test('calculates fixed money (DA) discount correctly', () {
        final discountType = 'money';
        final discountValue = 100.0;

        final discountAmount = discountType == 'percentage'
            ? (subtotal * discountValue / 100.0).clamp(0.0, subtotal)
            : discountValue.clamp(0.0, subtotal);
        final netTotal = (subtotal - discountAmount).clamp(0.0, double.infinity);

        expect(discountAmount, 100.0);
        expect(netTotal, 3100.0);
      });

      test('calculates percentage (%) discount correctly', () {
        final discountType = 'percentage';
        final discountValue = 10.0; // 10%

        final discountAmount = discountType == 'percentage'
            ? (subtotal * discountValue / 100.0).clamp(0.0, subtotal)
            : discountValue.clamp(0.0, subtotal);
        final netTotal = (subtotal - discountAmount).clamp(0.0, double.infinity);

        expect(discountAmount, 320.0);
        expect(netTotal, 2880.0);
      });

      test('clamps discount so it cannot exceed gross subtotal', () {
        final discountType = 'money';
        final discountValue = 5000.0; // exceeds 3200.0

        final discountAmount = discountType == 'percentage'
            ? (subtotal * discountValue / 100.0).clamp(0.0, subtotal)
            : discountValue.clamp(0.0, subtotal);
        final netTotal = (subtotal - discountAmount).clamp(0.0, double.infinity);

        expect(discountAmount, 3200.0);
        expect(netTotal, 0.0);
      });

      test('handles 100% discount correctly', () {
        final discountType = 'percentage';
        final discountValue = 100.0;

        final discountAmount = discountType == 'percentage'
            ? (subtotal * discountValue / 100.0).clamp(0.0, subtotal)
            : discountValue.clamp(0.0, subtotal);
        final netTotal = (subtotal - discountAmount).clamp(0.0, double.infinity);

        expect(discountAmount, 3200.0);
        expect(netTotal, 0.0);
      });

      test('re-scales percentage discount dynamically when subtotal changes', () {
        final discountType = 'percentage';
        final discountValue = 15.0; // 15%

        // Subtotal before adding soins (only acts)
        final actsSubtotal = 2500.0;
        final discountBefore = discountType == 'percentage'
            ? (actsSubtotal * discountValue / 100.0).clamp(0.0, actsSubtotal)
            : discountValue.clamp(0.0, actsSubtotal);
        expect(discountBefore, 375.0);

        // Subtotal after adding soins
        final combinedSubtotal = 3200.0;
        final discountAfter = discountType == 'percentage'
            ? (combinedSubtotal * discountValue / 100.0).clamp(0.0, combinedSubtotal)
            : discountValue.clamp(0.0, combinedSubtotal);
        expect(discountAfter, 480.0);
      });
    });

    group('Doctor Commission Discount Calculations', () {
      final subtotal = 3200.0;
      final grossCommission = 1120.0; // 1000.0 acts + 120.0 soins

      test('calculates proportional commission discount with percentage patient discount', () {
        final patientDiscountType = 'percentage';
        final patientDiscountVal = 10.0; // 10%
        final applyDoctorDiscount = true;
        final commissionDiscountType = 'proportional';

        final discountAmount = (subtotal * patientDiscountVal / 100.0).clamp(0.0, subtotal);
        expect(discountAmount, 320.0);

        final rate = subtotal > 0 ? (discountAmount / subtotal) : 0.0;
        final commissionDiscount = applyDoctorDiscount
            ? (grossCommission * rate).clamp(0.0, grossCommission)
            : 0.0;
        final netCommission = (grossCommission - commissionDiscount).clamp(0.0, double.infinity);

        expect(commissionDiscount, 112.0); // 10% of 1120
        expect(netCommission, 1008.0);
      });

      test('calculates proportional commission discount with fixed DA patient discount', () {
        final patientDiscountAmount = 160.0; // 160 / 3200 = 5%
        final applyDoctorDiscount = true;
        final commissionDiscountType = 'proportional';

        final rate = subtotal > 0 ? (patientDiscountAmount / subtotal) : 0.0;
        final commissionDiscount = applyDoctorDiscount
            ? (grossCommission * rate).clamp(0.0, grossCommission)
            : 0.0;
        final netCommission = (grossCommission - commissionDiscount).clamp(0.0, double.infinity);

        expect(commissionDiscount, 56.0); // 5% of 1120
        expect(netCommission, 1064.0);
      });

      test('calculates custom percentage commission discount', () {
        final applyDoctorDiscount = true;
        final customPercent = 50.0; // Doctor waives 50% commission

        final commissionDiscount = applyDoctorDiscount
            ? (grossCommission * customPercent / 100.0).clamp(0.0, grossCommission)
            : 0.0;
        final netCommission = (grossCommission - commissionDiscount).clamp(0.0, double.infinity);

        expect(commissionDiscount, 560.0);
        expect(netCommission, 560.0);
      });

      test('calculates custom fixed money (DA) commission discount', () {
        final applyDoctorDiscount = true;
        final customAmount = 200.0; // Doctor discounts 200 DA from commission

        final commissionDiscount = applyDoctorDiscount
            ? customAmount.clamp(0.0, grossCommission)
            : 0.0;
        final netCommission = (grossCommission - commissionDiscount).clamp(0.0, double.infinity);

        expect(commissionDiscount, 200.0);
        expect(netCommission, 920.0);
      });

      test('leaves doctor commission 100% untouched when applyDoctorDiscount is false', () {
        final applyDoctorDiscount = false;
        final commissionDiscount = applyDoctorDiscount
            ? (grossCommission * 0.10).clamp(0.0, grossCommission)
            : 0.0;
        final netCommission = (grossCommission - commissionDiscount).clamp(0.0, double.infinity);

        expect(commissionDiscount, 0.0);
        expect(netCommission, 1120.0);
      });

      test('scales individual PaymentService line items proportionally', () {
        final commissionDiscountAmount = 112.0; // 10% discount
        final commissionRatio = grossCommission > 0
            ? (1.0 - (commissionDiscountAmount / grossCommission)).clamp(0.0, 1.0)
            : 1.0;

        expect(commissionRatio, 0.90);

        final scaledPaymentServices = [
          ...acts.map((a) => PaymentService(
            serviceId: a.serviceId,
            serviceName: a.serviceName,
            servicePrice: a.price,
            doctorCommission: (a.doctorCommission * commissionRatio).clamp(0.0, a.price),
            serviceType: 'act',
          )),
          ...soins.map((s) => PaymentService(
            serviceId: s.id,
            serviceName: s.nom,
            servicePrice: s.price,
            doctorCommission: (s.doctorCommission * commissionRatio).clamp(0.0, s.price),
            serviceType: 'soin',
          )),
        ];

        expect(scaledPaymentServices[0].doctorCommission, 540.0); // 600 * 0.9
        expect(scaledPaymentServices[1].doctorCommission, 360.0); // 400 * 0.9
        expect(scaledPaymentServices[2].doctorCommission, 45.0);  // 50 * 0.9
        expect(scaledPaymentServices[3].doctorCommission, 63.0);  // 70 * 0.9

        final totalScaledCommission = scaledPaymentServices.fold(0.0, (sum, s) => sum + s.doctorCommission);
        expect(totalScaledCommission, 1008.0);
        expect(totalScaledCommission, grossCommission - commissionDiscountAmount);
      });
    });
  });
}
