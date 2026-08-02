import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/feed_repository.dart';
import 'data/services/feed_api_client.dart';
import 'data/services/feed_database.dart';
import 'ui/core/theme.dart';
import 'ui/features/feeds/view_models/feed_list_view_model.dart';
import 'ui/features/home/views/home_screen.dart';

void main() {
  runApp(const RssReaderApp());
}

class RssReaderApp extends StatelessWidget {
  const RssReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FeedApiClient>(
          create: (_) => FeedApiClient(),
          dispose: (_, client) => client.dispose(),
        ),
        Provider<FeedDatabase>(
          create: (_) => FeedDatabase(),
          dispose: (_, database) => database.close(),
        ),
        ChangeNotifierProvider<FeedRepository>(
          create: (context) => FeedRepository(
            apiClient: context.read<FeedApiClient>(),
            database: context.read<FeedDatabase>(),
          ),
        ),
        // Kept at the root so the unread badge stays in sync across screens.
        ChangeNotifierProvider<FeedListViewModel>(
          create: (context) =>
              FeedListViewModel(repository: context.read<FeedRepository>()),
        ),
      ],
      child: MaterialApp(
        title: 'RSS Reader',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const HomeScreen(),
      ),
    );
  }
}
