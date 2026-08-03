import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../bloc/owner_bloc.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  int _activeTab = 0; // 0 = Facilities, 1 = Analytics

  @override
  void initState() {
    super.initState();
    // Load turfs on mount
    context.read<OwnerBloc>().add(LoadOwnerTurfs());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_activeTab == 0) {
                context.read<OwnerBloc>().add(LoadOwnerTurfs());
              } else {
                context.read<OwnerBloc>().add(LoadOwnerAnalyticsRequested());
              }
            },
          ),
        ],
      ),
      floatingActionButton: _activeTab == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/owner/turfs/add'),
              backgroundColor: primaryColor,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Add Facility',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: BlocConsumer<OwnerBloc, OwnerState>(
        listener: (context, state) {
          if (state is OwnerLoaded) {
            if (state.actionSuccessMsg != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.actionSuccessMsg!),
                  backgroundColor: Colors.green,
                ),
              );
              context.read<OwnerBloc>().add(ClearOwnerStatus());
            }

            if (state.actionError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.actionError!),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
              context.read<OwnerBloc>().add(ClearOwnerStatus());
            }
          }
        },
        builder: (context, state) {
          if (state is OwnerLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is OwnerFailure) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Failed to load dashboard: ${state.error}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<OwnerBloc>().add(LoadOwnerTurfs()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is OwnerLoaded) {
            return Column(
              children: [
                // 1. Selector segment bar
                _buildSegmentBar(primaryColor),
                const SizedBox(height: 16),

                // 2. Tab contents
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _activeTab == 0
                        ? _buildFacilitiesTab(
                            context,
                            state.turfs,
                            primaryColor,
                            theme,
                          )
                        : _buildAnalyticsTab(
                            context,
                            state.analytics,
                            primaryColor,
                            theme,
                          ),
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSegmentBar(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF151D30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activeTab = 0;
                });
                context.read<OwnerBloc>().add(LoadOwnerTurfs());
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _activeTab == 0 ? primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'My Fields',
                  style: TextStyle(
                    color: _activeTab == 0 ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activeTab = 1;
                });
                context.read<OwnerBloc>().add(LoadOwnerAnalyticsRequested());
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _activeTab == 1 ? primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'Occupancy & Revenue',
                  style: TextStyle(
                    color: _activeTab == 1 ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilitiesTab(
    BuildContext context,
    List<dynamic> turfs,
    Color primaryColor,
    ThemeData theme,
  ) {
    if (turfs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.business_outlined,
              size: 64,
              color: Colors.white38,
            ),
            const SizedBox(height: 16),
            const Text(
              'No facilities registered yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/owner/turfs/add'),
              child: const Text('Register Turf Now'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<OwnerBloc>().add(LoadOwnerTurfs());
      },
      child: ListView.builder(
        itemCount: turfs.length,
        itemBuilder: (context, index) {
          final turf = turfs[index];
          final courts = turf['courts'] as List<dynamic>? ?? [];
          final status = turf['status'] as String? ?? 'PENDING';

          Color badgeColor = Colors.orange;
          if (status == 'APPROVED' || status == 'ACTIVE') {
            badgeColor = Colors.green;
          }
          if (status == 'REJECTED') {
            badgeColor = Colors.red;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            color: const Color(0xFF151D30),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${courts.length} Pitches',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    turf['name'],
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    turf['address'],
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const Divider(height: 24, color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${(turf['basePricePerHour'] as num).toInt()}/hr Base',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              _showGenerateSlotsSheet(context, turf);
                            },
                            child: const Text(
                              'Generate Slots',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              _showCourtsManager(context, turf);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white10,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text(
                              'Courts',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsTab(
    BuildContext context,
    Map<String, dynamic>? analytics,
    Color primaryColor,
    ThemeData theme,
  ) {
    if (analytics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalRevenue = (analytics['totalRevenue'] as num).toDouble();
    final totalBookings = analytics['totalBookings'] as int;
    final utilization = (analytics['utilizationRate'] as num).toDouble();
    final recentBookings = analytics['recentBookings'] as List<dynamic>? ?? [];
    final monthlyStats = analytics['monthlyStats'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: () async {
        context.read<OwnerBloc>().add(LoadOwnerAnalyticsRequested());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Grid
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Total Earnings',
                    value: '₹${totalRevenue.toInt()}',
                    icon: Icons.currency_rupee,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Direct Bookings',
                    value: totalBookings.toString(),
                    icon: Icons.calendar_month,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildKpiCard(
              title: 'Field Occupancy Rate',
              value: '${(utilization * 100).toStringAsFixed(0)}% Occupied',
              icon: Icons.percent,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),

            // Graph Chart Section
            Text(
              'Monthly Performance Overview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF151D30),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              padding: const EdgeInsets.all(16),
              child: CustomPaint(
                painter: _AnalyticsBarChartPainter(monthlyStats),
                child: Container(),
              ),
            ),
            const SizedBox(height: 28),

            // Recent activity lists
            Text(
              'Recent Booking Logs',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            if (recentBookings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'No bookings logged yet.',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentBookings.length,
                itemBuilder: (context, index) {
                  final b = recentBookings[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151D30),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b['userName'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${b['courtName']} • ${b['date']}',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '₹${(b['amount'] as num).toInt()}',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151D30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  void _showGenerateSlotsSheet(BuildContext context, dynamic turf) {
    final startController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final endController = TextEditingController(
      text: DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now().add(const Duration(days: 7))),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151D30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate Slots: ${turf['name']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Generate court reservation slots based on active templates. Duplicates will be skipped automatically.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: startController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Start Date (YYYY-MM-DD)',
                  hintStyle: TextStyle(color: Colors.white38),
                  labelText: 'Start Date',
                  labelStyle: TextStyle(color: Colors.white60),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: endController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'End Date (YYYY-MM-DD)',
                  hintStyle: TextStyle(color: Colors.white38),
                  labelText: 'End Date',
                  labelStyle: TextStyle(color: Colors.white60),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final start = startController.text.trim();
                    final end = endController.text.trim();
                    if (start.isNotEmpty && end.isNotEmpty) {
                      Navigator.pop(sheetContext);
                      context.read<OwnerBloc>().add(
                        GenerateSlotsRequested(
                          turfId: turf['id'],
                          startDate: start,
                          endDate: end,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Run Generation Engine',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCourtsManager(BuildContext context, dynamic turf) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151D30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final courts = turf['courts'] as List<dynamic>? ?? [];

            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              turf['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Pitch / Courts list',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _showAddCourtDialog(context, turf['id']);
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Court'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32, color: Colors.white10),
                  if (courts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: Center(
                        child: Text(
                          'No courts added under this facility yet.',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: courts.length,
                      itemBuilder: (context, index) {
                        final court = courts[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    court['name'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    court['type'],
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    '₹${(court['pricePerHour'] as num).toInt()}/hr',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.schedule,
                                      color: Colors.white70,
                                    ),
                                    onPressed: () {
                                      _showTemplatesManager(context, court);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCourtDialog(BuildContext context, String turfId) {
    final nameController = TextEditingController();
    final typeController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF151D30),
        title: const Text(
          'Add Court / Pitch',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Court Name (e.g. Pitch A)',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: typeController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Type (e.g. 5-a-side Turf)',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Price Per Hour (INR)',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(priceController.text.trim());
              final name = nameController.text.trim();
              final type = typeController.text.trim();

              if (name.isNotEmpty &&
                  type.isNotEmpty &&
                  price != null &&
                  price > 0) {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
                context.read<OwnerBloc>().add(
                  AddCourtRequested(
                    turfId: turfId,
                    name: name,
                    type: type,
                    pricePerHour: price,
                    sports: const ['c1234567-89ab-cdef-0123-456789abcdef'],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid court details'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text(
              'Save Pitch',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showTemplatesManager(BuildContext context, dynamic court) {
    context.read<OwnerBloc>().add(LoadCourtTemplatesRequested(court['id']));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151D30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return MultiBlocProvider(
          providers: [BlocProvider.value(value: context.read<OwnerBloc>())],
          child: BlocBuilder<OwnerBloc, OwnerState>(
            builder: (context, state) {
              List<dynamic> templates = [];
              if (state is OwnerLoaded) {
                templates = state.templates;
              }

              return Container(
                padding: EdgeInsets.only(
                  top: 24,
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${court['name']} Templates',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Configure weekly operational slots',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            _showAddTemplateDialog(context, court['id']);
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Slot'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32, color: Colors.white10),
                    if (templates.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(
                          child: Text(
                            'No slot templates configured yet.',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 250,
                        child: ListView.builder(
                          itemCount: templates.length,
                          itemBuilder: (context, index) {
                            final template = templates[index];
                            final dayName = _getDayName(
                              template['dayOfWeek'] as int,
                            );
                            final overrideText =
                                template['priceOverride'] != null
                                ? '₹${(template['priceOverride'] as num).toInt()} Override'
                                : 'Base Price';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white10),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$dayName: ${template['startTime']} - ${template['endTime']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    overrideText,
                                    style: TextStyle(
                                      color: template['priceOverride'] != null
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showAddTemplateDialog(BuildContext context, String courtId) {
    int dayVal = 0;
    final startController = TextEditingController(text: "06:00");
    final endController = TextEditingController(text: "07:00");
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final daysList = [
            {'val': 0, 'name': 'Sunday'},
            {'val': 1, 'name': 'Monday'},
            {'val': 2, 'name': 'Tuesday'},
            {'val': 3, 'name': 'Wednesday'},
            {'val': 4, 'name': 'Thursday'},
            {'val': 5, 'name': 'Friday'},
            {'val': 6, 'name': 'Saturday'},
          ];

          return AlertDialog(
            backgroundColor: const Color(0xFF151D30),
            title: const Text(
              'Add Slot Template',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: dayVal,
                  dropdownColor: const Color(0xFF151D30),
                  style: const TextStyle(color: Colors.white),
                  items: daysList.map((d) {
                    return DropdownMenuItem<int>(
                      value: d['val'] as int,
                      child: Text(d['name'] as String),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() {
                        dayVal = v;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: startController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Start Time (e.g. 06:00)',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: endController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'End Time (e.g. 07:00)',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Price Override (Optional)',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final start = startController.text.trim();
                  final end = endController.text.trim();
                  final override = double.tryParse(priceController.text.trim());

                  if (start.isNotEmpty && end.isNotEmpty) {
                    Navigator.pop(dialogContext);
                    Navigator.pop(context);
                    context.read<OwnerBloc>().add(
                      CreateCourtTemplateRequested(
                        courtId: courtId,
                        dayOfWeek: dayVal,
                        startTime: start,
                        endTime: end,
                        priceOverride: override,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                ),
                child: const Text(
                  'Save Slot',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getDayName(int d) {
    final days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    if (d >= 0 && d < days.length) return days[d];
    return 'Sunday';
  }
}

class _AnalyticsBarChartPainter extends CustomPainter {
  final List<dynamic> monthlyStats;

  _AnalyticsBarChartPainter(this.monthlyStats);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    if (monthlyStats.isEmpty) {
      // Draw placeholder text
      textPainter.text = const TextSpan(
        text: 'No performance history logs available.',
        style: TextStyle(color: Colors.white38, fontSize: 12),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
      return;
    }

    // 1. Calculate boundaries and metrics scales
    final maxRevenue = monthlyStats
        .map((e) => (e['revenue'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);
    final maxVal = maxRevenue > 0 ? maxRevenue : 1000.0;

    const double padding = 20.0;
    final double graphWidth = size.width - 2 * padding;
    final double graphHeight = size.height - 30.0;

    final double barSpacing = graphWidth / (monthlyStats.length * 2);
    final double barWidth = barSpacing;

    // 2. Draw bars
    for (int i = 0; i < monthlyStats.length; i++) {
      final stat = monthlyStats[i];
      final month = stat['month'] as String;
      final revenue = (stat['revenue'] as num).toDouble();

      final double heightRatio = revenue / maxVal;
      final double barHeight = graphHeight * heightRatio;

      final double xPos =
          padding + i * (barWidth + barSpacing) + barSpacing / 2;
      final double yPos = graphHeight - barHeight;

      // Draw active bar
      paint.color = const Color(0xFF00E676); // Green bar indicator
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(xPos, yPos, barWidth, barHeight),
          const Radius.circular(4),
        ),
        paint,
      );

      // Draw label text
      textPainter.text = TextSpan(
        text: month,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(xPos + (barWidth - textPainter.width) / 2, graphHeight + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
