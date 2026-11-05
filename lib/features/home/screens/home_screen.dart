import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/model/banner_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../providers/home_provider.dart';
import '../widgets/category_tabs.dart';
import '../widgets/product_grid.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const _HomeView();
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> with TickerProviderStateMixin {
  bool _showSearch = false;
  final _searchController = TextEditingController();

  late final AnimationController _searchAnimationController;
  late final Animation<double> _searchHeightAnimation;
  late final Animation<double> _bannerOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _searchHeightAnimation = Tween<double>(begin: 110, end: 60).animate(
      CurvedAnimation(
          parent: _searchAnimationController, curve: Curves.easeOutCubic),
    );

    _bannerOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _searchAnimationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _showSearch = !_showSearch);

    if (_showSearch) {
      _searchAnimationController.forward();
    } else {
      _searchAnimationController.reverse();
      _searchController.clear();
      context.read<HomeProvider>().clearSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<HomeProvider>();

    // ── Loading ──
    if (provider.loading) {
      return const Scaffold(body: _HomeSkeleton());
    }

    // ── Error ──
    if (provider.error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(provider.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.read<HomeProvider>().refresh(),
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar با انیمیشن نرم ──
          AnimatedBuilder(
            animation: _searchAnimationController,
            builder: (context, _) => SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            expandedHeight: _searchHeightAnimation.value,
            backgroundColor:
                isDark ? AppColors.darkBackground : AppColors.lightBackground,
            elevation: 0,
            // ⬅️ منو به leading (سمت راست در RTL)
            leading: _showSearch
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 8,top: 2),
                    child: GestureDetector(
                      onTap: () => Scaffold.of(context).openDrawer(),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(Icons.menu_rounded),
                        ),
                      ),
                    ),
                  ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder:
                    (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _showSearch
                    ? _SearchField(
                        key: const ValueKey('search'),
                        controller: _searchController,
                        isDark: isDark,
                        onChanged: (q) =>
                            context.read<HomeProvider>().setSearchQuery(q),
                        onClose: _toggleSearch,
                      )
                    : Padding(
                        padding: const EdgeInsets.only(
                            right: 38), // ← فاصله‌ی جدید برای جلوگیری از هم‌پوشانی
                        child: Column(
                          key: const ValueKey('title'),
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🍽️ منوی رستوران',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                              ),
                            ),
                            Text(
                              'بهترین غذاها در یک کلیک',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            // ⬅️ actions: جستجو + نوتیفیکیشن
            actions: _showSearch
                ? []
                : [
                    IconButton(
                      icon: Icon(Icons.search_rounded,
                          color:
                              isDark ? AppColors.darkText : AppColors.lightText),
                      onPressed: _toggleSearch,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(Icons.notifications_rounded),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
          ),
          ),

          // ── بنر تبلیغاتی با انیمیشن Fade + Scale ──
          if (!_showSearch && provider.banners.isNotEmpty)
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _bannerOpacityAnimation,
                child: ScaleTransition(
                  scale: _bannerOpacityAnimation,
                  child: _PromoBannerCarousel(
                    banners: provider.banners,
                    isDark: isDark,
                  ),
                ),
              ),
            ),

          // ── تب‌های کتگوری (Sticky) ──
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabsDelegate(isDark: isDark),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── گرید محصولات ──
          const ProductGrid(),
        ],
      ),
    );
  }
}

// ── فیلد سرچ داخل AppBar ──
class _SearchField extends StatelessWidget {
  const _SearchField({
    super.key,
    required this.controller,
    required this.isDark,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final bool isDark;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        autofocus: true,
        textDirection: TextDirection.rtl,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
        decoration: InputDecoration(
          hintText: 'جستجوی غذا...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.primary, size: 20),
          suffixIcon: GestureDetector(
            onTap: onClose,
            child: Icon(Icons.close_rounded,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                size: 20),
          ),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        ),
      ),
    );
  }
}

// ── بنرهای زنده مدیریت‌شده از CRM ──
class _PromoBannerCarousel extends StatefulWidget {
  const _PromoBannerCarousel({required this.banners, required this.isDark});

  final List<BannerModel> banners;
  final bool isDark;

  @override
  State<_PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<_PromoBannerCarousel> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.94);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 196,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.banners.length,
        itemBuilder: (context, index) => _PromoBannerCard(
          banner: widget.banners[index],
          isDark: widget.isDark,
        ),
      ),
    );
  }
}

class _PromoBannerCard extends StatelessWidget {
  const _PromoBannerCard({required this.banner, required this.isDark});

  final BannerModel banner;
  final bool isDark;

  void _copyCode(BuildContext context) {
    final code = banner.discountCode?.trim() ?? '';
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('کد تخفیف $code کپی شد'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final headline = banner.promoTitle.trim().isNotEmpty
        ? banner.promoTitle.trim()
        : banner.title.trim();
    final code = banner.discountCode?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (banner.imageUrl.trim().isNotEmpty)
              CachedNetworkImage(
                imageUrl: banner.imageUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 220),
                placeholder: (_, __) => ShimmerSkeleton(
                  child: Container(
                    color: isDark
                        ? AppColors.darkSurface
                        : const Color(0xFFE9E1D9),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF5B1D19), Color(0xFFE53935)],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                  ),
                ),
              )
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5B1D19), Color(0xFFE53935)],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xE6000000),
                    Color(0x78000000),
                    Color(0x09000000),
                  ],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 14,
              bottom: 14,
              width: width * 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (banner.title.trim().isNotEmpty)
                    Text(
                      banner.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (headline.isNotEmpty)
                    Text(
                      headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  if (banner.subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      banner.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (code.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Material(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => _copyCode(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  code,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'کپی',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (banner.logoUrl != null && banner.logoUrl!.trim().isNotEmpty)
              Positioned(
                left: 14,
                top: 14,
                child: Container(
                  width: 58,
                  height: 58,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white70),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: CachedNetworkImage(
                      imageUrl: banner.logoUrl!,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const SizedBox.expand(),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blockColor = isDark ? const Color(0xFF252525) : Colors.white;
    Widget block({double? width, required double height, double radius = 12}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: blockColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return ShimmerSkeleton(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
        children: [
          Row(
            children: [
              Expanded(child: block(height: 34, radius: 10)),
              const SizedBox(width: 14),
              block(width: 40, height: 40, radius: 12),
            ],
          ),
          const SizedBox(height: 20),
          block(height: 174, radius: 22),
          const SizedBox(height: 20),
          Row(
            children: List.generate(
              4,
              (index) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: index == 3 ? 0 : 8),
                  child: block(height: 42, radius: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: block(height: 150, radius: 16)),
                const SizedBox(height: 9),
                block(height: 12, radius: 6),
                const SizedBox(height: 7),
                block(width: 90, height: 10, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sticky تب‌ها ──
class _StickyTabsDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabsDelegate({required this.isDark});
  final bool isDark;

  @override
  double get minExtent => 64;
  @override
  double get maxExtent => 64;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: Column(
        children: [
          if (overlapsContent)
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.06),
            ),
          const Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: CategoryTabs(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabsDelegate old) => old.isDark != isDark;
}