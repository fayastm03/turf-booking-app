import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/home_bloc.dart';
import '../domain/turf_models.dart';
import 'search_screen.dart';
import '../../booking/presentation/my_bookings_screen.dart';
import '../../notification/bloc/notification_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: _buildTabContent(_currentTabIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: theme.colorScheme.background,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.white38,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(int index) {
    if (index == 0) {
      return const _HomeDashboardContent();
    }
    if (index == 1) {
      return const SearchScreen();
    }
    if (index == 2) {
      return const MyBookingsScreen();
    }
    return const _ProfileSettingsContent();
  }
}

class _HomeDashboardContent extends StatelessWidget {
  const _HomeDashboardContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, homeState) {
        if (homeState is HomeLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (homeState is HomeFailure) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error loading turfs: ${homeState.error}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.read<HomeBloc>().add(LoadHomeData()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (homeState is HomeLoaded) {
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                context.read<HomeBloc>().add(LoadHomeData());
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // 1. Header Row
                    _buildHeader(context, homeState),
                    const SizedBox(height: 16),

                    // 2. Search Bar
                    _buildSearchBar(theme),
                    const SizedBox(height: 20),

                    // 3. Category selector horizontal scroll
                    _buildSportsCategories(context, homeState),
                    const SizedBox(height: 24),

                    // 4. Upcoming booking card
                    _buildUpcomingBookingCard(theme),
                    const SizedBox(height: 24),

                    // 5. Nearby Turfs Carousel
                    _buildSectionHeader(context, 'Nearby Turfs', () {
                      // Navigate to search list
                    }),
                    const SizedBox(height: 12),
                    _buildNearbyTurfsList(context, homeState.turfs),
                    const SizedBox(height: 24),

                    // 6. Recommended for you vertical cards
                    _buildSectionHeader(context, 'Recommended for you', () {
                      // Navigate to search list
                    }),
                    const SizedBox(height: 12),
                    _buildRecommendedTurfsList(context, homeState.turfs),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildHeader(BuildContext context, HomeLoaded state) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    
    // Retrieve user name from AuthBloc
    final authState = context.read<AuthBloc>().state;
    String userName = 'Guest';
    if (authState is Authenticated) {
      userName = authState.user['name'] ?? 'Alex';
    }

    return Row(
      children: [
        // Profile picture avatar placeholder
        const CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white12,
          backgroundImage: CachedNetworkImageProvider(
            'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&auto=format&fit=crop&q=80',
          ),
        ),
        const SizedBox(width: 12),
        // Greeting & location selector
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning, $userName',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _showCitySelector(context, state);
                },
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      '${state.selectedCity?.name ?? "Select Location"}, India',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Wallet Icon
        IconButton(
          icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 24),
          onPressed: () => context.push('/wallet'),
        ),
        // Notification bell with dynamic badge
        BlocBuilder<NotificationBloc, NotificationState>(
          builder: (context, state) {
            int count = 0;
            if (state is NotificationLoaded) {
              count = state.unreadCount;
            }

            return IconButton(
              icon: count > 0
                  ? Badge(
                      label: Text(count.toString()),
                      backgroundColor: Colors.redAccent,
                      textColor: Colors.white,
                      child: const Icon(Icons.notifications_none_outlined, color: Colors.white, size: 24),
                    )
                  : const Icon(Icons.notifications_none_outlined, color: Colors.white, size: 24),
              onPressed: () => context.push('/notifications'),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151D30),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white38),
          const SizedBox(width: 12),
          const Expanded(
            child: TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search turfs, sports...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.tune, color: theme.colorScheme.primary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSportsCategories(BuildContext context, HomeLoaded state) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: state.sports.length + 1, // +1 for "All" option
        itemBuilder: (context, index) {
          final isAllOption = index == 0;
          final sport = isAllOption ? null : state.sports[index - 1];
          final isSelected = isAllOption
              ? state.selectedSport == null
              : state.selectedSport?.id == sport?.id;

          final displayName = isAllOption ? 'All' : sport!.name;

          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: ChoiceChip(
              label: Text(displayName),
              selected: isSelected,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: const Color(0xFF151D30),
              selectedColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isSelected ? primaryColor : Colors.white10,
                ),
              ),
              avatar: isAllOption
                  ? null
                  : Icon(
                      _getSportIcon(sport!.name),
                      color: isSelected ? Colors.black : Colors.white60,
                      size: 16,
                    ),
              onSelected: (_) {
                context.read<HomeBloc>().add(SelectSport(sport));
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildUpcomingBookingCard(ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151D30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  'UPCOMING',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.white60),
                  SizedBox(width: 4),
                  Text(
                    '2h 15m left',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Kickoff at 5:00 PM',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Turf City Main Arena • Court 4',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text(
                    'Get Directions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.qr_code, color: Colors.white),
                  onPressed: () {
                    // Show QR Code sheet
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback onSeeAll) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            'See all',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyTurfsList(BuildContext context, List<Turf> turfs) {
    if (turfs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Text(
            'No turfs available in this filter range',
            style: TextStyle(color: Colors.white38),
          ),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: turfs.length,
        itemBuilder: (context, index) {
          final turf = turfs[index];
          final photoUrl = turf.images.isNotEmpty
              ? turf.images.first.url
              : 'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?w=600&auto=format&fit=crop&q=80';

          return GestureDetector(
            onTap: () {
              context.push('/turfs/${turf.id}');
            },
            child: Container(
              width: 240,
              margin: const EdgeInsets.only(right: 16),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: photoUrl,
                          height: 130,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.white10),
                          errorWidget: (context, url, error) => Container(color: Colors.white10),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: const Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  '4.8',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  turf.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                '₹${turf.basePricePerHour.toInt()}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '0.8 km • ${turf.address.split(',').last.trim()}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecommendedTurfsList(BuildContext context, List<Turf> turfs) {
    if (turfs.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: turfs.length,
      itemBuilder: (context, index) {
        final turf = turfs[index];
        final photoUrl = turf.images.isNotEmpty
            ? turf.images.first.url
            : 'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?w=600&auto=format&fit=crop&q=80';

        return GestureDetector(
          onTap: () {
            context.push('/turfs/${turf.id}');
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.white10),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  turf.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber, size: 14),
                                  SizedBox(width: 2),
                                  Text(
                                    '4.9',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${turf.city?.name ?? "Bangalore"} • Multi-sport Arena',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '• Available today',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '₹${turf.basePricePerHour.toInt()}/hr',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCitySelector(BuildContext context, HomeLoaded state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151D30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select City',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                itemCount: state.cities.length,
                itemBuilder: (context, index) {
                  final city = state.cities[index];
                  final isSelected = state.selectedCity?.id == city.id;

                  return ListTile(
                    title: Text(
                      city.name,
                      style: TextStyle(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      context.read<HomeBloc>().add(SelectCity(city));
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getSportIcon(String name) {
    switch (name.toLowerCase()) {
      case 'football':
        return Icons.sports_soccer;
      case 'cricket':
        return Icons.sports_cricket;
      case 'badminton':
        return Icons.sports_tennis;
      default:
        return Icons.sports;
    }
  }
}

class _ProfileSettingsContent extends StatelessWidget {
  const _ProfileSettingsContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        String name = 'Guest User';
        String email = 'Sign in to access settings';
        bool isLoggedIn = false;
        bool isPartner = false;

        if (state is Authenticated) {
          name = state.user['name'] ?? 'Guest User';
          email = state.user['email'] ?? '';
          isLoggedIn = true;
          final roles = state.user['roles'];
          if (roles is List) {
            isPartner = roles.contains('OWNER') || roles.contains('ADMIN');
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // User info header card
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: primaryColor.withOpacity(0.15),
                    child: Text(
                      name.substring(0, 1).toUpperCase(),
                      style: TextStyle(color: primaryColor, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Settings Option list
              if (isLoggedIn) ...[
                _buildSettingsTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Turf Wallet',
                  subtitle: 'Manage card credits & top-ups',
                  onTap: () => context.push('/wallet'),
                ),
                if (isPartner)
                  _buildSettingsTile(
                    icon: Icons.business_outlined,
                    title: 'Manage Facilities (Partner Mode)',
                    subtitle: 'Register fields & manage courts',
                    onTap: () => context.push('/owner'),
                  ),
                const Divider(height: 32, color: Colors.white10),
                _buildSettingsTile(
                  icon: Icons.logout,
                  title: 'Sign Out',
                  subtitle: 'Logout from this account',
                  color: Colors.redAccent,
                  onTap: () {
                    context.read<AuthBloc>().add(LogoutRequested());
                  },
                ),
              ] else ...[
                _buildSettingsTile(
                  icon: Icons.login,
                  title: 'Sign In',
                  subtitle: 'Log in to manage bookings and wallet',
                  onTap: () => context.go('/login'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Color color = Colors.white70,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151D30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color == Colors.white70 ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
      ),
    );
  }
}
