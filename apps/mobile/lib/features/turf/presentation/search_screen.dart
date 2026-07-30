import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../bloc/search_bloc.dart';
import '../bloc/home_bloc.dart';
import '../domain/turf_models.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    context.read<SearchBloc>().add(SearchQuerySubmitted(query));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<SearchBloc, SearchState>(
          listener: (context, state) {
            if (state is SearchFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is SearchLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is SearchLoaded) {
              _searchController.text = state.query;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // 1. Search Bar Header
                    _buildSearchBar(context, theme, state),
                    const SizedBox(height: 16),

                    // 2. Recent Searches
                    if (state.recentSearches.isNotEmpty) _buildRecentSearches(context, state.recentSearches),

                    const SizedBox(height: 16),

                    // 3. Search results header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Results (${state.results.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (state.selectedCityId != null || state.selectedSportId != null || state.selectedCourtType != null)
                          GestureDetector(
                            onTap: () {
                              context.read<SearchBloc>().add(ClearAllFilters());
                            },
                            child: Text(
                              'Clear Filters',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 4. Search Results Scroll List
                    Expanded(
                      child: _buildResultsList(context, state.results),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, ThemeData theme, SearchLoaded state) {
    final primaryColor = theme.colorScheme.primary;

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF151D30),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white38),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _onSearch,
                    decoration: InputDecoration(
                      hintText: 'Search fields, arenas...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearch('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Filter button triggers sheet
        GestureDetector(
          onTap: () {
            _showFilterSheet(context, state);
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF151D30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (state.selectedCityId != null || state.selectedSportId != null || state.selectedCourtType != null)
                    ? primaryColor
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.tune,
              color: (state.selectedCityId != null || state.selectedSportId != null || state.selectedCourtType != null)
                  ? primaryColor
                  : Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearches(BuildContext context, List<String> searches) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Searches',
              style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            GestureDetector(
              onTap: () {
                context.read<SearchBloc>().add(ClearRecentSearchesRequested());
              },
              child: const Icon(Icons.delete_outline, color: Colors.white30, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: searches.length,
            itemBuilder: (context, index) {
              final term = searches[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ActionChip(
                  label: Text(term),
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                  backgroundColor: const Color(0xFF151D30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  onPressed: () {
                    _searchController.text = term;
                    _onSearch(term);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList(BuildContext context, List<Turf> results) {
    if (results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              'No fields found matching your query',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final turf = results[index];
        final photoUrl = turf.images.isNotEmpty
            ? turf.images.first.url
            : 'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?w=600&auto=format&fit=crop&q=80';

        return GestureDetector(
          onTap: () {
            context.push('/turfs/${turf.id}');
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: CachedNetworkImage(
                          imageUrl: photoUrl,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.white10),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: const Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 14),
                              SizedBox(width: 4),
                              Text(
                                '4.8',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
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
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                turf.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Text(
                              '₹${turf.basePricePerHour.toInt()}/hr',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          turf.address,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Available Today',
                                  style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            // Sport Category Icon Tag
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: const Row(
                                children: [
                                  Icon(Icons.sports_soccer, size: 14, color: Colors.white60),
                                  SizedBox(width: 4),
                                  Text(
                                    'Football',
                                    style: TextStyle(color: Colors.white60, fontSize: 11),
                                  ),
                                ],
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
        );
      },
    );
  }

  void _showFilterSheet(BuildContext context, SearchLoaded searchState) {
    // Load lists from HomeBloc
    final homeState = context.read<HomeBloc>().state;
    if (homeState is! HomeLoaded) return;

    String? tempCityId = searchState.selectedCityId;
    String? tempSportId = searchState.selectedSportId;
    String? tempCourtType = searchState.selectedCourtType;
    String tempSortBy = searchState.sortBy;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151D30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final theme = Theme.of(context);
            final primaryColor = theme.colorScheme.primary;

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters & Sort',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. Sort By Options
                  const Text('Sort By', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'Name (A-Z)',
                        selected: tempSortBy == 'name_asc',
                        onSelected: (_) => setStateSheet(() => tempSortBy = 'name_asc'),
                        primaryColor: primaryColor,
                      ),
                      _buildFilterChip(
                        label: 'Price: Low to High',
                        selected: tempSortBy == 'price_asc',
                        onSelected: (_) => setStateSheet(() => tempSortBy = 'price_asc'),
                        primaryColor: primaryColor,
                      ),
                      _buildFilterChip(
                        label: 'Price: High to Low',
                        selected: tempSortBy == 'price_desc',
                        onSelected: (_) => setStateSheet(() => tempSortBy = 'price_desc'),
                        primaryColor: primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. City Filter
                  const Text('Select City', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'All Cities',
                        selected: tempCityId == null,
                        onSelected: (_) => setStateSheet(() => tempCityId = null),
                        primaryColor: primaryColor,
                      ),
                      ...homeState.cities.map((city) {
                        return _buildFilterChip(
                          label: city.name,
                          selected: tempCityId == city.id,
                          onSelected: (_) => setStateSheet(() => tempCityId = city.id),
                          primaryColor: primaryColor,
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. Sport Filter
                  const Text('Sport Category', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'All Sports',
                        selected: tempSportId == null,
                        onSelected: (_) => setStateSheet(() => tempSportId = null),
                        primaryColor: primaryColor,
                      ),
                      ...homeState.sports.map((sport) {
                        return _buildFilterChip(
                          label: sport.name,
                          selected: tempSportId == sport.id,
                          onSelected: (_) => setStateSheet(() => tempSportId = sport.id),
                          primaryColor: primaryColor,
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 4. Court Type
                  const Text('Court Surface Type', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'All Surfaces',
                        selected: tempCourtType == null,
                        onSelected: (_) => setStateSheet(() => tempCourtType = null),
                        primaryColor: primaryColor,
                      ),
                      _buildFilterChip(
                        label: 'Indoor',
                        selected: tempCourtType == 'Indoor',
                        onSelected: (_) => setStateSheet(() => tempCourtType = 'Indoor'),
                        primaryColor: primaryColor,
                      ),
                      _buildFilterChip(
                        label: 'Outdoor',
                        selected: tempCourtType == 'Outdoor',
                        onSelected: (_) => setStateSheet(() => tempCourtType = 'Outdoor'),
                        primaryColor: primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            context.read<SearchBloc>().add(ClearAllFilters());
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Reset All', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            context.read<SearchBloc>().add(
                                  UpdateFilters(
                                    cityId: tempCityId ?? 'all',
                                    sportId: tempSportId ?? 'all',
                                    courtType: tempCourtType ?? 'all',
                                    sortBy: tempSortBy,
                                  ),
                                );
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
    required Color primaryColor,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: Colors.white.withOpacity(0.04),
      selectedColor: primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: selected ? primaryColor : Colors.white10),
      ),
      onSelected: onSelected,
    );
  }
}
