import 'package:flutter/material.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SoftBackground(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const ScreenHeader(
              title: 'Statistiques',
              subtitle: "Vue d'ensemble des signalements",
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: '0',
                          label: 'Signalements',
                          icon: Icons.shield_outlined,
                          color: AppTheme.primary,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: StatTile(
                          value: '0',
                          label: 'En cours',
                          icon: Icons.hourglass_bottom_rounded,
                          color: AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: '0',
                          label: 'Clôturés',
                          icon: Icons.check_circle_outline_rounded,
                          color: AppTheme.success,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: StatTile(
                          value: '0',
                          label: 'Urgents',
                          icon: Icons.priority_high_rounded,
                          color: AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // TODO: brancher les vraies données et graphiques.
            const EmptyState(
              icon: Icons.bar_chart_rounded,
              title: 'Graphiques à venir',
              message:
                  'Les statistiques détaillées seront disponibles prochainement.',
            ),
          ],
        ),
      ),
    );
  }
}
