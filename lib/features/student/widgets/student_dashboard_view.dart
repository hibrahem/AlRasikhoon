import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/day_beads.dart';
import '../../../shared/widgets/hero_header.dart';
import '../../../shared/widgets/level_progression_widget.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/stat_tile.dart';

/// What the current meeting IS, for presentation. The mapping from the
/// curriculum's `PacedSession` happens in the screen; the view only knows
/// how each kind looks (green = lesson/تلقين action, gold = exam
/// achievement, maroon = سرد attention).
enum DashboardSessionKind { lesson, talqeen, exam, sard }

@immutable
class DashboardSessionInfo {
  final DashboardSessionKind kind;
  final String title;
  final String subtitle;

  /// The passage (e.g. «سورة النبأ ١–١٦») for lesson/تلقين kinds.
  final String? passage;

  /// Explanatory body text (the تلقين reassurance line).
  final String? note;

  const DashboardSessionInfo({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.passage,
    this.note,
  });
}

/// Everything the dashboard renders, pre-derived. The view computes
/// nothing — it is the presentation half of the screen, and the preview
/// harness renders it with mock data.
@immutable
class StudentDashboardData {
  final String name;
  final int percent;
  final double fraction;
  final int juzMemorized;
  final int currentLevel;
  final int streakDays;

  /// Last seven days, today first — see [DayBeads].
  final List<bool> weekBeads;
  final int passedSessions;
  final int totalSessions;
  final List<int> unlockedLevels;
  final List<int> completedLevels;
  final DashboardSessionInfo? session;

  const StudentDashboardData({
    required this.name,
    required this.percent,
    required this.fraction,
    required this.juzMemorized,
    required this.currentLevel,
    required this.streakDays,
    required this.weekBeads,
    required this.passedSessions,
    required this.totalSessions,
    required this.unlockedLevels,
    required this.completedLevels,
    required this.session,
  });
}

/// The redesigned student dashboard: full-bleed green hero (greeting, gold
/// progress ring, day-beads) with the content column pulled up over the
/// hero's ogee — session ticket, bento stat row, home-practice card, and
/// the untouched journey expander.
class StudentDashboardView extends StatelessWidget {
  final StudentDashboardData data;

  /// Slot for the provider-bound home-practice card (the preview passes a
  /// mock-backed one).
  final Widget? practiceCard;

  /// Slot for the provider-bound "متى الختم؟" forecast card — how long until
  /// the student finishes the whole Quran at their configured plan.
  final Widget? forecastCard;

  /// Slot rendered above the content column (e.g. the guardian's child
  /// switcher).
  final Widget? leading;

  const StudentDashboardView({
    super.key,
    required this.data,
    this.practiceCard,
    this.forecastCard,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHero(context, tokens),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) leading!,
                  if (data.session != null)
                    _EntranceSlot(
                      index: 0,
                      child: _SessionTicketCard(session: data.session!),
                    ),
                  const SizedBox(height: AppDimens.space16),
                  _EntranceSlot(index: 1, child: _buildBentoRow(context)),
                  if (practiceCard != null) ...[
                    const SizedBox(height: AppDimens.space16),
                    _EntranceSlot(index: 2, child: practiceCard!),
                  ],
                  if (forecastCard != null) ...[
                    const SizedBox(height: AppDimens.space16),
                    _EntranceSlot(index: 3, child: forecastCard!),
                  ],
                  const SizedBox(height: AppDimens.space16),
                  _buildJourneyExpander(context, tokens),
                  const SizedBox(height: AppDimens.space24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, AppTokens tokens) {
    return HeroHeader(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'السلام عليكم',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: tokens.onHeroMuted,
                      ),
                    ),
                    Text(
                      data.name,
                      style: GoogleFonts.amiri(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: tokens.onHero,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.gold.withValues(alpha: 0.15),
                ),
                alignment: Alignment.center,
                child: Text(
                  data.name.isNotEmpty ? data.name.characters.first : '؟',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: tokens.gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ProgressRing(
            fraction: data.fraction,
            percent: data.percent,
            trackColor: tokens.onHero.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 12),
          Text(
            'حفظت ${data.juzMemorized} من 30 جزءاً',
            style: GoogleFonts.cairo(fontSize: 14, color: tokens.onHeroMuted),
          ),
          const SizedBox(height: 14),
          // FittedBox: the beads row scales down rather than overflowing on
          // very narrow viewports (split-screen, resize transitions).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: DayBeads(
              days: data.weekBeads,
              dimColor: tokens.onHero.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoRow(BuildContext context) {
    final tokens = context.tokens;
    // Tiles take their natural heights (identical content = identical
    // heights; a taller tile is a bento feature, not a bug — and the
    // intrinsic pass rounds fractionally and overflows).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Streak leads (start side = visual dominance top-right in RTL) and
        // carries the screen's one asymmetric corner.
        Expanded(
          child: StatTile(
            icon: Icons.timeline,
            value: '${data.streakDays}',
            // Same wording as the practice screen's streak tile — the two
            // bento tiles describe the same number.
            label: 'أيام متتالية',
            accent: tokens.gold,
            accentCorner: true,
          ),
        ),
        const SizedBox(width: AppDimens.space12),
        Expanded(
          child: StatTile(
            icon: Icons.task_alt,
            value: '${data.passedSessions}',
            label: 'حلقة ناجحة',
            accent: tokens.green,
          ),
        ),
        const SizedBox(width: AppDimens.space12),
        Expanded(
          child: StatTile(
            icon: Icons.stairs_outlined,
            value: '${data.currentLevel}',
            label: 'المستوى',
            accent: tokens.green,
          ),
        ),
      ],
    );
  }

  /// The level journey, untouched by the redesign except for the card
  /// surface it sits on: the full ten-tile grid stays collapsed behind the
  /// same expander.
  Widget _buildJourneyExpander(BuildContext context, AppTokens tokens) {
    final brightness = Theme.of(context).brightness;
    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        boxShadow: AppShadows.card(brightness),
        border: brightness == Brightness.dark
            ? Border.all(color: tokens.rewardDim)
            : null,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
          title: Text(
            'رحلة المستويات',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          // The count must not REPLACE the expand affordance: the chevron
          // stays beside it so the tile still reads as expandable.
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${data.completedLevels.length}/10 مكتمل',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, color: tokens.sepia),
            ],
          ),
          children: [
            LevelProgressionWidget(
              currentLevel: data.currentLevel,
              unlockedLevels: data.unlockedLevels,
              completedLevels: data.completedLevels,
            ),
          ],
        ),
      ),
    );
  }
}

/// The current meeting as a "ticket": a 4dp kind-colored accent bar on the
/// start edge, an icon medallion, Amiri title, and — for lesson/تلقين —
/// the passage on a soft inset panel in Amiri.
class _SessionTicketCard extends StatelessWidget {
  final DashboardSessionInfo session;

  const _SessionTicketCard({required this.session});

  static const _icons = {
    DashboardSessionKind.lesson: Icons.menu_book,
    DashboardSessionKind.talqeen: Icons.record_voice_over,
    DashboardSessionKind.exam: Icons.workspace_premium_outlined,
    DashboardSessionKind.sard: Icons.record_voice_over,
  };

  static const _passageLabels = {
    DashboardSessionKind.lesson: 'الحفظ الجديد',
    DashboardSessionKind.talqeen: 'المقطع الجديد',
  };

  Color _accent(AppTokens tokens) => switch (session.kind) {
    DashboardSessionKind.lesson || DashboardSessionKind.talqeen => tokens.green,
    DashboardSessionKind.exam => tokens.gold,
    DashboardSessionKind.sard => tokens.maroon,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final brightness = Theme.of(context).brightness;
    final accent = _accent(tokens);
    final passageLabel = _passageLabels[session.kind];

    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusCardLg),
        boxShadow: AppShadows.card(brightness),
        border: brightness == Brightness.dark
            ? Border.all(color: tokens.rewardDim)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      // Stack, not a stretch-Row: the accent bar is painted over the card's
      // start edge, so the content alone sizes the card (a stretch-Row needs
      // an intrinsic pass, which rounds fractionally and overflows).
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: accent),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        _icons[session.kind],
                        size: 22,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            style: GoogleFonts.amiri(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: tokens.ink,
                            ),
                          ),
                          Text(
                            session.subtitle,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.sepia),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (session.passage != null && passageLabel != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsetsDirectional.all(12),
                    decoration: BoxDecoration(
                      color: tokens.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          passageLabel,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: tokens.sepia),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.passage!,
                          style: GoogleFonts.amiri(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: tokens.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (session.note != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    session.note!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One-shot entrance: fade + 12dp slide-up, 250ms, staggered 40ms per
/// [index]. Collapses to nothing under reduced motion.
class _EntranceSlot extends StatefulWidget {
  final int index;
  final Widget child;

  const _EntranceSlot({required this.index, required this.child});

  @override
  State<_EntranceSlot> createState() => _EntranceSlotState();
}

class _EntranceSlotState extends State<_EntranceSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _fade = curve;
    _slide = Tween(begin: const Offset(0, 12), end: Offset.zero).animate(curve);

    Future.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(offset: _slide.value, child: child),
      ),
      child: widget.child,
    );
  }
}
