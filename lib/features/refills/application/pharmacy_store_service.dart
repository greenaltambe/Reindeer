import 'package:flutter/foundation.dart';
import 'package:reindeer/core/platform/system_channel.dart';
import 'package:url_launcher/url_launcher.dart';

/// Supported online pharmacy destinations and government generic stores.
enum PharmacyStore { tata1mg, apollo, netmeds, janAushadhi }

/// Service to formulate search queries and open external online pharmacies
/// or find government Jan Aushadhi stores on Google Maps.
class PharmacyStoreService {
  const PharmacyStoreService();

  /// Builds the deep link or web search URL for a given pharmacy store.
  static String buildUrl({
    required PharmacyStore store,
    required String query,
    String? composition,
  }) {
    final cleanQuery = query.trim();
    final cleanComposition = composition?.trim() ?? '';

    switch (store) {
      case PharmacyStore.tata1mg:
        // Tata 1mg search URL: searches for brand or salt composition
        final target = cleanQuery.isNotEmpty ? cleanQuery : cleanComposition;
        return 'https://www.1mg.com/search/all?name=${Uri.encodeComponent(target)}';

      case PharmacyStore.apollo:
        // Apollo Pharmacy search URL
        final target = cleanQuery.isNotEmpty ? cleanQuery : cleanComposition;
        return 'https://www.apollopharmacy.in/search-medicines/${Uri.encodeComponent(target)}';

      case PharmacyStore.netmeds:
        // Netmeds search URL
        final target = cleanQuery.isNotEmpty ? cleanQuery : cleanComposition;
        return 'https://www.netmeds.com/products?q=${Uri.encodeQueryComponent(target).replaceAll('+', '%20')}';

      case PharmacyStore.janAushadhi:
        // Jan Aushadhi Kendra search on Google Maps near current location
        return 'https://www.google.com/maps/search/Jan+Aushadhi+Kendra+near+me';
    }
  }

  /// Safely opens the external store URL in the device browser or native app.
  static Future<bool> openStore({
    required PharmacyStore store,
    required String query,
    String? composition,
  }) async {
    final urlString = buildUrl(
      store: store,
      query: query,
      composition: composition,
    );
    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('url_launcher failed for $urlString: $e');
    }

    // Fallback: try via SystemChannel if available on Android
    try {
      // If Android system channel supports openUrl or shareText
      return await SystemChannel.shareText(
        urlString,
        title: 'Open medicine link',
      );
    } catch (_) {
      return false;
    }
  }
}
