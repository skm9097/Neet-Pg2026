import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/github_sync_service.dart';
import '../../services/gemini_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/soft_widgets.dart';

class SyncStatusScreen extends StatefulWidget {
  final GeminiService gemini;
  const SyncStatusScreen({super.key, required this.gemini});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  List<SyncLogEntry> _log = [];
  int _pendingCount = 0;
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final log = await GithubSyncService.getSyncLog();
    final pending = await GithubSyncService.pendingCount();
    if (mounted) setState(() {
      _log = log;
      _pendingCount = pending;
      _loading = false;
    });
  }

  Future<void> _flushNow() async {
    final pat = await GithubSyncService.getPat();
    if (pat == null || pat.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No GitHub PAT configured. Go to Settings → GitHub Sync.'),
        backgroundColor: AppTheme.incorrect,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _syncing = true);
    try {
      final pushed = await GithubSyncService.flushOfflineQueue(widget.gemini);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(pushed > 0
              ? 'Pushed $pushed mistake${pushed == 1 ? '' : 's'} to GitHub.'
              : 'Nothing pending to push.'),
          backgroundColor: AppTheme.correct,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: AppTheme.incorrect,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
        await _reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pushCount = _log.where((e) => e.action == 'push').length;
    final errorCount = _log.where((e) => e.action == 'error').length;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          const CompactGradientHeader(
            title: 'GitHub Sync Status',
            subtitle: 'Mistake pipeline & push history',
            icon: Icons.cloud_sync_rounded,
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : RefreshIndicator(
                    onRefresh: _reload,
                    color: AppTheme.primary,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                      children: [
                        // Summary row
                        Row(children: [
                          _statCard(pushCount.toString(), 'Pushed', AppTheme.correct, Icons.upload_rounded),
                          const SizedBox(width: 10),
                          _statCard(_pendingCount.toString(), 'Pending', AppTheme.accent, Icons.pending_rounded),
                          const SizedBox(width: 10),
                          _statCard(errorCount.toString(), 'Errors', AppTheme.incorrect, Icons.error_outline_rounded),
                        ]),
                        const SizedBox(height: 14),
                        // Action buttons
                        Row(children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _syncing ? null : _flushNow,
                              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                              icon: _syncing
                                  ? const SizedBox(width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.sync_rounded, size: 18),
                              label: Text(_syncing ? 'Syncing…'
                                  : _pendingCount > 0 ? 'Sync $_pendingCount pending' : 'Sync Now'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _log.isEmpty ? null : () async {
                              await GithubSyncService.clearLog();
                              _reload();
                            },
                            icon: Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.inkFaint),
                            label: Text('Clear', style: TextStyle(color: AppTheme.inkFaint)),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        // Repo location card
                        _RepoCard(),
                        const SizedBox(height: 20),
                        // Log header
                        if (_log.isEmpty)
                          SoftEmptyState(
                            icon: Icons.cloud_off_rounded,
                            title: 'No sync activity yet',
                            message: 'Mistakes will appear here after your first quiz session.',
                          )
                        else ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text('Activity Log',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.ink)),
                          ),
                          ...(_log.take(100).map((e) => _LogTile(entry: e))),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.inkFaint)),
        ]),
      ),
    );
  }
}

class _RepoCard extends StatelessWidget {
  static const _url = 'github.com/skm9097/Neet-Pg2026/tree/main/mistakes';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.greenTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text('Where to find your mistake files',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppTheme.primary)),
        ]),
        const SizedBox(height: 8),
        Text(
          'Files are pushed to the main branch of your repo, inside the mistakes/ folder, organised by subject.',
          style: TextStyle(fontSize: 12, color: AppTheme.inkSoft, height: 1.5),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onLongPress: () {
            Clipboard.setData(const ClipboardData(text: 'https://$_url'));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('URL copied to clipboard'),
              backgroundColor: AppTheme.primary,
              behavior: SnackBarBehavior.floating,
            ));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.20)),
            ),
            child: Row(children: [
              Icon(Icons.link_rounded, size: 13, color: AppTheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_url,
                  style: TextStyle(
                    fontSize: 11.5, color: AppTheme.primary,
                    fontFamily: 'monospace', fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text('long-press to copy',
                style: TextStyle(fontSize: 10, color: AppTheme.inkFaint)),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Note: switch to the main branch on GitHub, not the dev branch.',
          style: TextStyle(fontSize: 11, color: AppTheme.inkFaint, fontStyle: FontStyle.italic),
        ),
      ]),
    );
  }
}

class _LogTile extends StatelessWidget {
  final SyncLogEntry entry;
  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isError = entry.action == 'error';
    final isQueue = entry.action == 'queue';
    final isSession = entry.action == 'session';

    Color color;
    IconData icon;
    if (isError) {
      color = AppTheme.incorrect;
      icon = Icons.error_outline_rounded;
    } else if (isQueue) {
      color = AppTheme.accent;
      icon = Icons.pending_rounded;
    } else if (isSession) {
      color = AppTheme.lavender;
      icon = Icons.assignment_rounded;
    } else {
      color = AppTheme.correct;
      icon = Icons.cloud_done_rounded;
    }

    final dt = entry.timestamp;
    final timeStr = '${dt.month}/${dt.day} ${_p(dt.hour)}:${_p(dt.minute)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isError ? color.withValues(alpha: 0.3) : AppTheme.line),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              entry.detail,
              style: TextStyle(fontSize: 12.5, color: AppTheme.ink, fontWeight: FontWeight.w500),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(timeStr, style: TextStyle(fontSize: 11, color: AppTheme.inkFaint)),
          ]),
        ),
      ]),
    );
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}
