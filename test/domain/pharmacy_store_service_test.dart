import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/refills/application/pharmacy_store_service.dart';

void main() {
  group('PharmacyStoreService', () {
    test('builds Tata 1mg search URL correctly', () {
      final url = PharmacyStoreService.buildUrl(
        store: PharmacyStore.tata1mg,
        query: 'Telma 40',
        composition: 'Telmisartan 40mg',
      );
      expect(url, 'https://www.1mg.com/search/all?name=Telma%2040');
    });

    test('builds Tata 1mg search URL with composition fallback when query is empty', () {
      final url = PharmacyStoreService.buildUrl(
        store: PharmacyStore.tata1mg,
        query: '',
        composition: 'Telmisartan 40mg',
      );
      expect(url, 'https://www.1mg.com/search/all?name=Telmisartan%2040mg');
    });

    test('builds Apollo 24/7 search URL correctly', () {
      final url = PharmacyStoreService.buildUrl(
        store: PharmacyStore.apollo247,
        query: 'Metformin 500mg',
      );
      expect(url, 'https://www.apollo247.com/search-medicines/Metformin%20500mg');
    });

    test('builds Netmeds search URL correctly', () {
      final url = PharmacyStoreService.buildUrl(
        store: PharmacyStore.netmeds,
        query: 'Dolo 650',
      );
      expect(url, 'https://www.netmeds.com/catalogsearch/result/Dolo%20650/all');
    });

    test('builds Jan Aushadhi Kendra search URL to Google Maps', () {
      final url = PharmacyStoreService.buildUrl(
        store: PharmacyStore.janAushadhi,
        query: 'Amlodipine',
      );
      expect(url, 'https://www.google.com/maps/search/Jan+Aushadhi+Kendra+near+me');
    });
  });
}
