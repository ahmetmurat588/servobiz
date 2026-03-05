// ServoBiz Widget Tests
//
// Bu dosya uygulamanın ana widget'larını test eder.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:servobiz/main.dart';

void main() {
  group('ServoBiz Ana Sayfa Testleri', () {
    testWidgets('Ana sayfa yükleniyor mu testi', (WidgetTester tester) async {
      // Uygulamayı başlat
      await tester.pumpWidget(const ServoBizApp());
      await tester.pumpAndSettle();

      // Ana menü butonlarının var olduğunu kontrol et
      expect(find.text('YENİ CİHAZ KAYDET'), findsOneWidget);
      expect(find.text('CİHAZ DURUMU GÜNCELLE'), findsOneWidget);
      expect(find.text('CİHAZ LİSTESİ'), findsOneWidget);
    });

    testWidgets('Giriş butonu görünüyor mu testi', (WidgetTester tester) async {
      await tester.pumpWidget(const ServoBizApp());
      await tester.pumpAndSettle();

      // Giriş butonunun var olduğunu kontrol et
      expect(find.text('GİRİŞ YAP'), findsOneWidget);
    });

    testWidgets('Onay Bekleyenler butonu görünüyor mu testi', (WidgetTester tester) async {
      await tester.pumpWidget(const ServoBizApp());
      await tester.pumpAndSettle();

      // Onay Bekleyenler butonunun var olduğunu kontrol et
      expect(find.text('ONAY BEKLEYENLER'), findsOneWidget);
    });
  });
}
