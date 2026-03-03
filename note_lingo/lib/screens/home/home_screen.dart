import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notes_provider.dart';
import '../../widgets/note_card.dart';
import '../recording/recording_screen.dart';
import '../library/notes_library_screen.dart';
import '../profile/profile_screen.dart';

// ── Palette ────────────────────────────────────────────────────────
const _bgTop = Color(0xFF6AABF8);
const _bgMid = Color(0xFF9AC8FB);
const _bgBot = Color(0xFFEFF5FF);
const _deep = Color(0xFF2356C8);
const _primary = Color(0xFF4F8EF7);
const _textDark = Color(0xFF0E1A3A);
const _textGrey = Color(0xFF6B7A99);
const _border = Color(0xFFD0DFFF);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotesProvider>().loadNotes();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgBot,
        extendBody: true,
        body: Stack(
          children: [
            // ── Fixed full-screen gradient — does NOT scroll ──────
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_bgTop, _bgMid, _bgBot],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.40, 1.0],
                  ),
                ),
              ),
            ),

            // ── Fixed decorative orbs — do NOT scroll ─────────────
            Positioned(
              top: -30,
              right: -40,
              child: _Orb(
                size: 200,
                color: const Color(0xFF5AA0F8).withOpacity(0.20),
              ),
            ),
            Positioned(
              top: size.height * 0.15,
              left: -45,
              child: _Orb(
                size: 140,
                color: const Color(0xFF88BFFB).withOpacity(0.16),
              ),
            ),
            Positioned(
              bottom: size.height * 0.22,
              right: 10,
              child: _Orb(size: 80, color: _deep.withOpacity(0.07)),
            ),

            // ── Scrollable content on top ──────────────────────────
            _navIndex == 0
                ? _HomeBody(
                    searchCtrl: _searchCtrl,
                    searchQuery: _searchQuery,
                    onSearch: (v) => setState(() => _searchQuery = v),
                  )
                : _navIndex == 1
                ? const NotesLibraryScreen(embedded: true)
                : const ProfileScreen(embedded: true),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          index: _navIndex,
          onTap: (i) => setState(() => _navIndex = i),
        ),
        floatingActionButton: _navIndex == 0 ? _RecordFab() : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// HOME BODY — transparent so the fixed gradient shows through
// ══════════════════════════════════════════════════════════════════

class _HomeBody extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String searchQuery;
  final ValueChanged<String> onSearch;

  const _HomeBody({
    required this.searchCtrl,
    required this.searchQuery,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notes = context.watch<NotesProvider>();
    final displayNotes = notes.filteredNotes(searchQuery);
    final name = auth.currentUser?.displayName?.split(' ').first ?? 'there';

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // greeting row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(),
                              style: TextStyle(
                                fontSize: 13,
                                color: _textDark.withOpacity(0.55),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: _textDark,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _AvatarBtn(name: auth.currentUser?.displayName ?? 'U'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _StatsRow(
                    total: notes.notes.length,
                    favorites: notes.favoriteCount,
                    minutes: notes.totalMinutes,
                  ),
                  const SizedBox(height: 20),

                  _RecordBanner(),
                  const SizedBox(height: 20),

                  // white search bar
                  _WhiteSearchBar(
                    controller: searchCtrl,
                    query: searchQuery,
                    onChanged: onSearch,
                    hint: 'Search notes…',
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Text(
                        searchQuery.isEmpty ? 'Recent Notes' : 'Search Results',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      const Spacer(),
                      if (notes.notes.isNotEmpty)
                        Text(
                          '${displayNotes.length} notes',
                          style: TextStyle(
                            fontSize: 13,
                            color: _textGrey.withOpacity(0.8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),

        if (notes.isLoading)
          SliverFillRemaining(
            hasScrollBody: false,
            child: const Padding(
              padding: EdgeInsets.only(bottom: 100),
              child: _LoadingSkeleton(),
            ),
          )
        else if (displayNotes.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: _EmptyState(hasSearch: searchQuery.isNotEmpty),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + i * 60),
                  curve: Curves.easeOut,
                  builder: (_, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - v)),
                      child: child,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NoteCard(note: displayNotes[i]),
                  ),
                ),
                childCount: displayNotes.length,
              ),
            ),
          ),
          // Bottom space so last card clears the FAB + nav bar
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ],
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

// ══════════════════════════════════════════════════════════════════
// WHITE SEARCH BAR — reusable, no dark theme leakage
// Export this if you want to use it in Library/Recording too
// ══════════════════════════════════════════════════════════════════

class _WhiteSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final String hint;
  final ValueChanged<String> onChanged;

  const _WhiteSearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
    this.hint = 'Search…',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A7CF5).withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: _primary,
        style: const TextStyle(
          fontSize: 14,
          color: _textDark,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: _textGrey.withOpacity(0.55),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: _primary.withOpacity(0.70),
          ),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: _textGrey.withOpacity(0.65),
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// STATS ROW
// ══════════════════════════════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  final int total, favorites, minutes;
  const _StatsRow({
    required this.total,
    required this.favorites,
    required this.minutes,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _StatTile(emoji: '📝', value: '$total', label: 'Notes'),
      const SizedBox(width: 10),
      _StatTile(emoji: '⭐', value: '$favorites', label: 'Starred'),
      const SizedBox(width: 10),
      _StatTile(emoji: '🕐', value: '${minutes}m', label: 'Recorded'),
    ],
  );
}

class _StatTile extends StatelessWidget {
  final String emoji, value, label;
  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A7CF5).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _textDark,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: _textGrey.withOpacity(0.8)),
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// RECORD BANNER
// ══════════════════════════════════════════════════════════════════

class _RecordBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecordingScreen()),
    ),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6BAAF8), _deep],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Recording',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to record — AI handles the rest',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.78),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white.withOpacity(0.80),
            size: 16,
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// FAB
// ══════════════════════════════════════════════════════════════════

class _RecordFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF6BAAF8), _deep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: _primary.withOpacity(0.40),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecordingScreen()),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Record',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// AVATAR BUTTON
// ══════════════════════════════════════════════════════════════════

class _AvatarBtn extends StatelessWidget {
  final String name;
  const _AvatarBtn({required this.name});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    ),
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6BAAF8), _deep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({this.hasSearch = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.80),
            shape: BoxShape.circle,
            border: Border.all(color: _border),
          ),
          child: Icon(
            hasSearch ? Icons.search_off_rounded : Icons.note_alt_outlined,
            color: _textGrey,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          hasSearch ? 'No notes found' : 'No notes yet',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasSearch
              ? 'Try different keywords'
              : 'Tap Record to create your first AI-powered note',
          style: TextStyle(fontSize: 14, color: _textGrey.withOpacity(0.85)),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// LOADING SKELETON
// ══════════════════════════════════════════════════════════════════

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 110,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// BOTTOM NAV
// ══════════════════════════════════════════════════════════════════

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.92),
      border: Border(top: BorderSide(color: _border, width: 1)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF4A7CF5).withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, -3),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              active: index == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.folder_outlined,
              activeIcon: Icons.folder_rounded,
              label: 'Library',
              active: index == 1,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              active: index == 2,
              onTap: () => onTap(2),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            color: active ? _primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            active ? activeIcon : icon,
            color: active ? _primary : _textGrey,
            size: 24,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? _primary : _textGrey,
          ),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// ORB HELPER
// ══════════════════════════════════════════════════════════════════

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ),
    ),
  );
}
