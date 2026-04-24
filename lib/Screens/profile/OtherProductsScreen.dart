import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/theme.dart';

class OtherProductsScreen extends StatelessWidget {
  const OtherProductsScreen({super.key});

  final List<Map<String, String>> apps = const [
    {
      'name': 'RevivePix: AI Photo Enhancer',
      'description': 'Restore Old & Blurry Photos',
      'icon': 'https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/4d/55/89/4d5589fe-2697-9f32-a2a6-788da1e1bb0e/Placeholder.mill/400x400bb.webp',
      'url': 'https://apps.apple.com/us/app/revivepix-ai-photo-enhancer/id6759591110',
    },
    {
      'name': 'Smart Sole: AI Shoe Try-On',
      'description': 'Virtual Fitting & Style AI',
      'icon': 'https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/e3/74/5d/e3745d56-9fab-e720-796b-970c7dcd11a9/Placeholder.mill/400x400bb.webp',
      'url': 'https://apps.apple.com/us/app/smart-sole-ai-shoe-try-on/id6759153898',
    },
    {
      'name': 'Smart Closet: Your AI Stylist',
      'description': 'Closet Organize-Outfit planner',
      'icon': 'https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/6d/fa/4b/6dfa4bbb-2be5-2233-9cdc-784ed977ad60/Placeholder.mill/400x400bb.webp',
      'url': 'https://apps.apple.com/us/app/smart-closet-your-ai-stylist/id1263105601',
    },
  ];

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.secondaryColor,
      appBar: AppBar(
        toolbarHeight: AppTheme.appBarHeight(context),
        foregroundColor: AppTheme.primaryColor,
        backgroundColor: AppTheme.secondaryColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Other Products",
          style: AppTheme.appBarTitleStyle(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          itemCount: apps.length,
          itemBuilder: (context, index) {
            final app = apps[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () => _launchURL(app['url']!),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.tilescolor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.stokecolor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: app['icon']!,
                          width: 60,
                          height: 60,
                          placeholder: (context, url) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[200],
                            child: const Icon(Icons.error, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app['name']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF2D2B4E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              app['description']!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
