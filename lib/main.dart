import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dio/dio.dart';
import 'dart:convert';

import 'local_notifications.dart';

@Preview(name: 'My Test Text')
Widget myTestView() {
  return Image.asset(
    'packages/maestro_e2e_sample/assets/images/150x150.png',
  );
}

@Preview(name: 'My Sample Text')
Widget myHomeView() {
  return const ProviderScope(child: HomeView());
}

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomeView());
  }
}

final dio = Dio();

Future<Joke> fetchRandomJoke() async {
  // Fetching a random joke from a public API
  final response = await dio.get<Map<String, Object?>>(
    'https://official-joke-api.appspot.com/random_joke',
  );

  return Joke.fromJson(response.data!);
}

final randomJokeProvider = FutureProvider<Joke>((ref) async {
  // Using the fetchRandomJoke function to get a random joke
  return fetchRandomJoke();
});

class Joke {
  Joke({
    required this.type,
    required this.setup,
    required this.punchline,
    required this.id,
  });

  factory Joke.fromJson(Map<String, Object?> json) {
    return Joke(
      type: json['type']! as String,
      setup: json['setup']! as String,
      punchline: json['punchline']! as String,
      id: json['id']! as int,
    );
  }

  final String type;
  final String setup;
  final String punchline;
  final int id;
}

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localNotificationsControllerProvider);
    final randomJoke = ref.watch(randomJokeProvider);
    final openedPayload = ref.watch(openedNotificationPayloadProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Random Joke Generator')),
      body: SafeArea(
        child: Column(
          children: [
            if (openedPayload != null && openedPayload.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Semantics(
                  identifier: 'opened-notification-payload',
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _OpenedFromNotification(payload: openedPayload),
                    ),
                  ),
                ),
              ),
            if (randomJoke.isRefreshing)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            Expanded(
              child: Center(
                child: switch (randomJoke) {
                  AsyncValue(:final value?) => Semantics(
                    identifier: 'joke-text',
                    child: SelectableText(
                      '${value.setup}\n\n${value.punchline}',
                      key: const Key('joke-text'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  AsyncValue(error: != null) => const Text(
                    'Error fetching joke',
                  ),
                  AsyncValue() => const CircularProgressIndicator(),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    identifier: 'notification-joke',
                    button: true,
                    child: ElevatedButton(
                      key: const Key('notification-joke'),
                      onPressed:
                          kIsWeb
                              ? null
                              : () async {
                                final joke = randomJoke.valueOrNull;
                                if (joke == null) return;
                                final payload = jsonEncode(<String, Object?>{
                                  'id': joke.id,
                                  'setup': joke.setup,
                                  'punchline': joke.punchline,
                                });
                                final controller = ref.read(
                                  localNotificationsControllerProvider.notifier,
                                );
                                final allowed =
                                    await controller
                                        .requestPermissionsIfNeeded();
                                if (!allowed) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('通知が許可されていないため送信できません'),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                await controller.showJoke(
                                  payload: payload,
                                  title: 'Joke',
                                  body: '${joke.setup}\n${joke.punchline}',
                                );
                              },
                      child: const Text('Send Notification of Joke'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    identifier: 'get-another-joke',
                    button: true,
                    child: ElevatedButton(
                      key: const Key('get-another-joke'),
                      onPressed: () => ref.invalidate(randomJokeProvider),
                      child: const Text('Get another joke'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenedFromNotification extends StatelessWidget {
  const _OpenedFromNotification({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    String? setup;
    String? punchline;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, Object?>) {
        setup = decoded['setup'] as String?;
        punchline = decoded['punchline'] as String?;
      }
    } catch (_) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Opened from notification',
          key: Key('opened-notification-title'),
        ),
        if (setup != null) ...[
          Semantics(
            identifier: 'opened-notification-setup',
            child: Text(setup!, key: const Key('opened-notification-setup')),
          ),
          if (punchline != null)
            Semantics(
              identifier: 'opened-notification-punchline',
              child: Text(
                punchline!,
                key: const Key('opened-notification-punchline'),
              ),
            ),
        ] else
          Text(payload, key: const Key('opened-notification-payload')),
      ],
    );
  }
}
