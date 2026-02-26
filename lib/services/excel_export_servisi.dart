import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/cihaz.dart';
import 'cihaz_servisi.dart';

class ExcelExportServisi {
  final CihazServisi _cihazServisi = CihazServisi();

  /// Tüm cihazları Excel dosyasına aktar (size attığım formatta)
  Future<void> cihazlariExcelExport() async {
    try {
      // İzin kontrolü
      if (!await _checkPermissions()) {
        throw Exception('Depolama izni verilmedi');
      }
      
      // Tüm cihazları al
      final cihazlar = _cihazServisi.cihazlar;
      
      if (cihazlar.isEmpty) {
        print('⚠️ Export yapılacak cihaz bulunamadı');
        return;
      }

      // Workbook oluştur
      final Workbook workbook = Workbook();
      
      // ETİKETLENDİ sayfası
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = "ETİKETLENDİ";

      // BAŞLIKLAR - Size attığınız Excel'deki sütun başlıkları
      final List<String> basliklar = [
        'Cihaz Durumu',
        'Tarih',
        'Cihaza Verilen No',
        'Cihaz Seri No',
        'Ürün',
        'Firma',
        'Yapılan İşlem',
        'İkinci Tarih',
        'Not 1',
        'Not 2',
        'Not 3',
        'Not 4'
      ];

      // Başlık stilini ayarla
      final style = workbook.styles.add('BaslikStili');
      style.backColor = '#4472C4';
      style.fontColor = '#FFFFFF';
      style.fontName = 'Calibri';
      style.fontSize = 11;
      style.bold = true;
      style.hAlign = HAlignType.center;
      style.borders.all.color = '#000000';
      style.borders.all.lineStyle = LineStyle.thin;

      // Başlıkları yaz
      for (int i = 0; i < basliklar.length; i++) {
        final range = sheet.getRangeByIndex(1, i + 1);
        range.setText(basliklar[i]);
        range.cellStyle = style;
      }

      // Sütun genişliklerini ayarla
      sheet.setColumnWidthInPixels(1, 25);  // Cihaz Durumu
      sheet.setColumnWidthInPixels(2, 15);  // Tarih
      sheet.setColumnWidthInPixels(3, 15);  // Cihaza Verilen No
      sheet.setColumnWidthInPixels(4, 25);  // Cihaz Seri No
      sheet.setColumnWidthInPixels(5, 35);  // Ürün
      sheet.setColumnWidthInPixels(6, 30);  // Firma
      sheet.setColumnWidthInPixels(7, 70);  // Yapılan İşlem
      sheet.setColumnWidthInPixels(8, 15);  // İkinci Tarih
      sheet.setColumnWidthInPixels(9, 15);  // Not 1
      sheet.setColumnWidthInPixels(10, 15); // Not 2
      sheet.setColumnWidthInPixels(11, 15); // Not 3
      sheet.setColumnWidthInPixels(12, 15); // Not 4

      // Veri stilini ayarla
      final dataStyle = workbook.styles.add('VeriStili');
      dataStyle.fontName = 'Calibri';
      dataStyle.fontSize = 11;
      dataStyle.borders.all.color = '#000000';
      dataStyle.borders.all.lineStyle = LineStyle.thin;

      // Verileri yaz (cihazları sondan başa doğru sırala - en yeniler en üstte)
      final sortedCihazlar = List<Cihaz>.from(cihazlar);
      sortedCihazlar.sort((a, b) {
        // ServoBiz No'ya göre tersten sırala (büyük numara daha yeni)
        return int.parse(b.servoBizNo).compareTo(int.parse(a.servoBizNo));
      });

      for (int i = 0; i < sortedCihazlar.length; i++) {
        final cihaz = sortedCihazlar[i];
        final rowIndex = i + 2; // 1. satır başlıklar, 2. satırdan itibaren veriler

        // Cihaz Durumu
        final durumRange = sheet.getRangeByIndex(rowIndex, 1);
        durumRange.setText(cihaz.durum.toUpperCase());
        durumRange.cellStyle = dataStyle;
        
        // Duruma göre renklendirme yap
        final durumStyle = workbook.styles.add('DurumStili_$i');
        durumStyle.fontName = 'Calibri';
        durumStyle.fontSize = 11;
        durumStyle.borders.all.color = '#000000';
        durumStyle.borders.all.lineStyle = LineStyle.thin;
        
        // Duruma göre arka plan rengi
        if (cihaz.durum.contains('Çıkış')) {
          durumStyle.backColor = '#C6EFCE'; // Yeşilimsi
        } else if (cihaz.durum.contains('Atolye')) {
          durumStyle.backColor = '#FFEB9C'; // Sarımsı
        } else if (cihaz.durum.contains('Test')) {
          durumStyle.backColor = '#BDD7EE'; // Mavimsi
        } else if (cihaz.durum.contains('Teslim')) {
          durumStyle.backColor = '#A9D08E'; // Açık yeşil
        }
        durumRange.cellStyle = durumStyle;

        // Tarih
        final tarihRange = sheet.getRangeByIndex(rowIndex, 2);
        tarihRange.setText(_formatTarih(cihaz.tarih));
        tarihRange.cellStyle = dataStyle;

        // Cihaza Verilen No (ServoBiz No)
        final noRange = sheet.getRangeByIndex(rowIndex, 3);
        noRange.setText(cihaz.servoBizNo);
        noRange.cellStyle = dataStyle;

        // Cihaz Seri No
        final seriNoRange = sheet.getRangeByIndex(rowIndex, 4);
        seriNoRange.setText(cihaz.seriNo);
        seriNoRange.cellStyle = dataStyle;

        // Ürün (Marka/Model)
        final urunRange = sheet.getRangeByIndex(rowIndex, 5);
        urunRange.setText(cihaz.markaModel);
        urunRange.cellStyle = dataStyle;

        // Firma
        final firmaRange = sheet.getRangeByIndex(rowIndex, 6);
        firmaRange.setText(cihaz.firmaIsmi);
        firmaRange.cellStyle = dataStyle;

        // Yapılan İşlem (Notlar)
        final islemRange = sheet.getRangeByIndex(rowIndex, 7);
        islemRange.setText(cihaz.notlar ?? '');
        islemRange.cellStyle = dataStyle;

        // İkinci Tarih (varsa son güncelleme tarihi)
        if (cihaz.sonDurumDegisiklikTarihi != null) {
          final ikinciTarihRange = sheet.getRangeByIndex(rowIndex, 8);
          ikinciTarihRange.setText(DateFormat('dd.MM.yyyy').format(cihaz.sonDurumDegisiklikTarihi!));
          ikinciTarihRange.cellStyle = dataStyle;
        }

        // Kaydeden (Not 1)
        final kaydedenRange = sheet.getRangeByIndex(rowIndex, 9);
        kaydedenRange.setText(cihaz.kaydedenKullaniciAdi ?? '');
        kaydedenRange.cellStyle = dataStyle;

        // Son Güncelleyen (Not 2)
        final guncelleyenRange = sheet.getRangeByIndex(rowIndex, 10);
        guncelleyenRange.setText(cihaz.sonGuncelleyen ?? '');
        guncelleyenRange.cellStyle = dataStyle;

        // Not 3 (boş)
        final not3Range = sheet.getRangeByIndex(rowIndex, 11);
        not3Range.setText('');
        not3Range.cellStyle = dataStyle;

        // Not 4 (boş)
        final not4Range = sheet.getRangeByIndex(rowIndex, 12);
        not4Range.setText('');
        not4Range.cellStyle = dataStyle;
      }

      // İkinci sayfa: ETİKETSİZ (örnek format)
      workbook.worksheets.add();
      final sheet2 = workbook.worksheets[1];
      sheet2.name = "ETİKETSİZ";
      
      // ETİKETSİZ sayfası için başlıklar
      final List<String> etiketsizBasliklar = [
        'Etiket Durumu',
        'Fotoğraf Durumu',
        'Kayıt Numarası',
        'Tarih',
        'Cihaz Seri No/Marka',
        'Ürün',
        'Firma'
      ];

      for (int i = 0; i < etiketsizBasliklar.length; i++) {
        final range = sheet2.getRangeByIndex(1, i + 1);
        range.setText(etiketsizBasliklar[i]);
        range.cellStyle = style;
      }

      // Excel dosyasını kaydet
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      // Dosya adını oluştur (tarih saat ekleyerek)
      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
      final fileName = 'ServoBiz_Cihazlar_$dateStr.xlsx';

      // Dosyayı Downloads klasörüne kaydet (Android için)
      Directory? downloadDir;
      
      if (Platform.isAndroid) {
        downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          downloadDir = await getExternalStorageDirectory();
        }
      } else {
        downloadDir = await getApplicationDocumentsDirectory();
      }

      final filePath = '${downloadDir?.path}/$fileName';
      final File file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      print('✅ Excel dosyası oluşturuldu: $filePath');
      print('📊 Toplam cihaz sayısı: ${cihazlar.length}');

      // Dosyayı aç
      await OpenFilex.open(filePath);

    } catch (e) {
      print('❌ Excel export hatası: $e');
      throw Exception('Excel export başarısız: $e');
    }
  }

  /// Tarih formatını düzenle (GG.AA.YYYY)
  String _formatTarih(String tarih) {
    try {
      if (tarih.contains('/')) {
        // Zaten GG/AA/YYYY formatındaysa
        final parts = tarih.split('/');
        if (parts.length == 3) {
          return '${parts[0]}.${parts[1]}.${parts[2]}';
        }
      } else if (tarih.contains('-')) {
        // YYYY-AA-GG formatındaysa
        final parts = tarih.split('-');
        if (parts.length == 3) {
          return '${parts[2]}.${parts[1]}.${parts[0]}';
        }
      }
      return tarih;
    } catch (e) {
      return tarih;
    }
  }

  /// İzinleri kontrol et ve iste
  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ (API 33) için farklı izin sistemi var
      // Downloads klasörüne yazmak için MANAGE_EXTERNAL_STORAGE gerekli
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        return true;
      }
      // Eski Android sürümleri için (10 ve altı)
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    return true;
  }
}