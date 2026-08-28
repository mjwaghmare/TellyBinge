import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_snackbar.dart';
import 'cubit/import_tv_time_cubit.dart';
import 'cubit/import_tv_time_state.dart';

class ImportTvTimePage extends StatelessWidget {
  const ImportTvTimePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ImportTvTimeCubit(tmdbClient: context.read<TmdbClient>()),
      child: BlocConsumer<ImportTvTimeCubit, ImportTvTimeState>(
        listener: (context, state) {
          if (state.status == ImportTvTimeStatus.completed) {
            AppSnackbar.showSuccess(context, 'Import completed successfully!');
            Navigator.pop(context);
          }

          if (state.status == ImportTvTimeStatus.failure) {
            AppSnackbar.showError(
              context,
              state.errorMessage ?? 'Import failed',
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<ImportTvTimeCubit>();

          return Scaffold(
            appBar: AppBar(title: const Text('Import TV Time')),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSpacing.gapH24,

                  const Icon(Icons.folder_zip, size: 72),

                  AppSpacing.gapH16,

                  Text(
                    'Import your TV Time GDPR backup',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.lg,
                  ),

                  const SizedBox(height: 30),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(state.fileName, textAlign: TextAlign.center),
                          AppSpacing.gapH16,
                          FilledButton(
                            onPressed:
                                state.status == ImportTvTimeStatus.processing
                                ? null
                                : cubit.pickZip,
                            child: const Text('Select ZIP'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  if (state.status == ImportTvTimeStatus.processing)
                    Column(
                      children: [
                        Text(
                          state.statusMessage,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.smBold,
                        ),
                        AppSpacing.gapH8,
                        LinearProgressIndicator(value: state.progress),
                      ],
                    ),

                  AppSpacing.gapH16,

                  FilledButton(
                    onPressed:
                        state.hasFile &&
                            state.status != ImportTvTimeStatus.processing
                        ? cubit.processZipLocally
                        : null,
                    child: const Text('Import'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
