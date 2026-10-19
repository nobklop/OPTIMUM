import 'package:flutter/material.dart';
import '../app_model.dart';
import '../data/service_account.dart';
import '../playback/model.dart';
import 'cosmos.dart';
import 'music_links.dart';

Future<void> showServiceAccounts(
  BuildContext context,
  AppModel model,
  PlaybackModel player,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => _ServiceAccounts(model: model, player: player),
  ),
);

class _ServiceAccounts extends StatelessWidget {
  final AppModel model;
  final PlaybackModel player;
  const _ServiceAccounts({required this.model, required this.player});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Аккаунты сервисов')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Ваша музыка из любимых сервисов',
          style: TextStyle(fontSize: 23),
        ),
        const SizedBox(height: 10),
        const Text(
          'Войдите в свой аккаунт и пользуйтесь его библиотекой внутри OPTIMUM. Вход сохраняется в отдельном веб-профиле приложения. API-ключи не нужны.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 24),
        for (final account in ServiceAccount.all) ...[
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        account.name,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  account.libraryUri.host,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () async {
                    await player.stop();
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ServicePlayer.account(
                          account: account,
                          model: model,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Войти и открыть библиотеку'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const Text(
          'Вход подтверждается самим сервисом. Плейлисты и лайки отображаются на его странице; в локальную библиотеку OPTIMUM они автоматически не копируются. Для смены аккаунта выйдите в меню сервиса и войдите снова.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ],
    ),
  );
}
