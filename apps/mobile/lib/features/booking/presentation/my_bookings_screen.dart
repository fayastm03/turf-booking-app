import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/booking_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  String _activeFilter = 'All'; // 'All', 'Upcoming', 'Completed', 'Cancelled'

  @override
  void initState() {
    super.initState();
    // Load bookings on mount if authenticated
    if (context.read<AuthBloc>().state is Authenticated) {
      context.read<BookingBloc>().add(LoadMyBookingsRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reservations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (context.read<AuthBloc>().state is Authenticated) {
                context.read<BookingBloc>().add(LoadMyBookingsRequested());
              }
            },
          ),
        ],
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, authState) {
          if (authState is Authenticated) {
            context.read<BookingBloc>().add(LoadMyBookingsRequested());
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            if (authState is! Authenticated) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 80, color: primaryColor.withOpacity(0.5)),
                      const SizedBox(height: 24),
                      Text(
                        'Access Your Reservations',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Please sign in to view your upcoming bookings and reservation history.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.go('/login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Sign In Now', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return BlocConsumer<BookingBloc, BookingState>(
              listener: (context, state) {
                if (state is CancellationSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reservation cancelled successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Refresh list
                  context.read<BookingBloc>().add(LoadMyBookingsRequested());
                }

                if (state is CancellationFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.error),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is MyBookingsLoadInProgress ||
                    state is CancellationLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is MyBookingsLoadFailure) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Failed to load bookings: ${state.error}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.read<BookingBloc>().add(
                            LoadMyBookingsRequested(),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (state is MyBookingsLoadSuccess) {
                  final filteredBookings = _filterBookings(state.bookings);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        // 1. Filter Chips Row
                        _buildFilterChips(primaryColor),
                        const SizedBox(height: 16),

                        // 2. Bookings List Scroll
                        Expanded(
                          child: _buildBookingsList(context, filteredBookings, theme),
                        ),
                      ],
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChips(Color primaryColor) {
    final filters = ['All', 'Upcoming', 'Completed', 'Cancelled'];

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filterName = filters[index];
          final isSelected = _activeFilter == filterName;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(filterName),
              selected: isSelected,
              backgroundColor: const Color(0xFF151D30),
              selectedColor: primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isSelected ? primaryColor : Colors.white10,
                ),
              ),
              onSelected: (_) {
                setState(() {
                  _activeFilter = filterName;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingsList(
    BuildContext context,
    List<dynamic> bookings,
    ThemeData theme,
  ) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.white38,
            ),
            const SizedBox(height: 16),
            Text(
              'No $_activeFilter reservations found',
              style: const TextStyle(color: Colors.white38, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Navigate back to home
                context.go('/');
              },
              child: const Text('Find Fields to Book'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final slot = booking['slot'];
        final court = slot['court'];
        final turf = court['turf'];
        final status = booking['status'] as String;

        final isUpcoming =
            _isUpcomingBooking(slot['date'], slot['startTime']) &&
            status.toUpperCase() == 'CONFIRMED';
        final isCancelled =
            status.toUpperCase() == 'CANCELLED' ||
            status.toUpperCase() == 'REFUNDED' ||
            status.toUpperCase() == 'EXPIRED';

        Color badgeColor = Colors.orange;
        if (isUpcoming) {
          badgeColor = Colors.green;
        } else if (isCancelled) {
          badgeColor = Colors.red;
        } else if (status.toUpperCase() == 'CONFIRMED') {
          badgeColor = Colors.blue; // Completed
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: isCancelled
              ? const Color(0xFF131A26).withValues(alpha: 0.4)
              : const Color(0xFF151D30),
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
                      '₹${(booking['amount'] as num).toInt()}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  turf['name'],
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isCancelled ? Colors.white38 : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${court['name']} • ${court['type']}',
                  style: TextStyle(
                    color: isCancelled ? Colors.white24 : Colors.white60,
                    fontSize: 13,
                  ),
                ),
                const Divider(height: 24, color: Colors.white10),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: isCancelled ? Colors.white24 : Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      slot['date'],
                      style: TextStyle(
                        color: isCancelled ? Colors.white24 : Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: isCancelled ? Colors.white24 : Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${slot['startTime']} - ${slot['endTime']}',
                      style: TextStyle(
                        color: isCancelled ? Colors.white24 : Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                // Action buttons for Upcoming tickets
                if (isUpcoming) ...[
                  const Divider(height: 24, color: Colors.white10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _confirmCancel(context, booking['id']),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Cancel Ticket',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code, color: Colors.white),
                          onPressed: () => _showQrSheet(context, booking),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<dynamic> _filterBookings(List<dynamic> list) {
    if (_activeFilter == 'All') return list;

    return list.where((b) {
      final slot = b['slot'];
      final status = b['status'] as String;

      final isUpcoming =
          _isUpcomingBooking(slot['date'], slot['startTime']) &&
          status.toUpperCase() == 'CONFIRMED';
      final isCancelled =
          status.toUpperCase() == 'CANCELLED' ||
          status.toUpperCase() == 'REFUNDED' ||
          status.toUpperCase() == 'EXPIRED';
      final isCompleted =
          !isUpcoming && !isCancelled && status.toUpperCase() == 'CONFIRMED';

      if (_activeFilter == 'Upcoming') return isUpcoming;
      if (_activeFilter == 'Cancelled') return isCancelled;
      if (_activeFilter == 'Completed') return isCompleted;
      return true;
    }).toList();
  }

  bool _isUpcomingBooking(String dateStr, String startTimeStr) {
    try {
      final slotDateTime = DateTime.parse('${dateStr}T$startTimeStr:00');
      return slotDateTime.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  void _confirmCancel(BuildContext context, String bookingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151D30),
        title: const Text(
          'Cancel Booking?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to cancel this booking? A refund will be initiated to your original payment method automatically.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<BookingBloc>().add(
                CancelBookingRequested(bookingId),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showQrSheet(BuildContext context, dynamic booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151D30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Show Check-in QR Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please present this ticket QR to the turf staff at check-in.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Simulated QR code drawing box
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                width: 180,
                height: 180,
                child: CustomPaint(painter: _QrSimulationPainter()),
              ),
              const SizedBox(height: 16),
              Text(
                'Ticket ID: ${booking['id'].toString().substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _QrSimulationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.0;

    // Draw standard QR-like corner squares
    const squareSize = 35.0;
    _drawSquare(canvas, 0, 0, squareSize, paint);
    _drawSquare(canvas, size.width - squareSize, 0, squareSize, paint);
    _drawSquare(canvas, 0, size.height - squareSize, squareSize, paint);

    // Draw some random grid paths in the middle to simulate standard QR code data blocks
    final randomPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4.0;

    canvas.drawLine(const Offset(50, 10), const Offset(100, 10), randomPaint);
    canvas.drawLine(const Offset(60, 30), const Offset(60, 80), randomPaint);
    canvas.drawLine(const Offset(80, 50), const Offset(130, 50), randomPaint);
    canvas.drawLine(const Offset(110, 20), const Offset(110, 90), randomPaint);

    canvas.drawLine(const Offset(10, 80), const Offset(80, 80), randomPaint);
    canvas.drawLine(const Offset(40, 100), const Offset(40, 140), randomPaint);
    canvas.drawLine(
      const Offset(100, 100),
      const Offset(140, 100),
      randomPaint,
    );
    canvas.drawLine(const Offset(120, 80), const Offset(120, 150), randomPaint);
    canvas.drawLine(const Offset(60, 120), const Offset(120, 120), randomPaint);
  }

  void _drawSquare(Canvas canvas, double x, double y, double s, Paint paint) {
    // Outer boundary
    canvas.drawRect(Rect.fromLTWH(x, y, s, s), Paint()..color = Colors.black);
    // Inner spacing
    canvas.drawRect(
      Rect.fromLTWH(x + 5, y + 5, s - 10, s - 10),
      Paint()..color = Colors.white,
    );
    // Center block
    canvas.drawRect(
      Rect.fromLTWH(x + 10, y + 10, s - 20, s - 20),
      Paint()..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
