import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../turf/domain/turf_models.dart';
import '../bloc/booking_bloc.dart';
import '../../wallet/bloc/wallet_bloc.dart';

class CheckoutScreen extends StatefulWidget {
  final String slotId;
  final Turf turf;
  final Slot slot;

  const CheckoutScreen({
    super.key,
    required this.slotId,
    required this.turf,
    required this.slot,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _promoController = TextEditingController();
  double _discount = 0.0;
  String? _appliedPromo;
  bool _isPromoApplied = false;

  // Convenience fees configuration
  final double _convenienceFee = 50.0;
  final double _taxRate = 0.18; // 18% GST

  // Payment method selection: 'RAZORPAY' or 'WALLET'
  String _paymentMethod = 'RAZORPAY';

  // Countdown timer for held slot
  Timer? _countdownTimer;
  int _secondsRemaining = 300; // 5 minutes
  bool _isHolding = false;
  String? _currentBookingId;

  @override
  void dispose() {
    _promoController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startHoldTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = 300;
      _isHolding = true;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _countdownTimer?.cancel();
        setState(() {
          _isHolding = false;
        });
        _showHoldExpiredDialog();
      }
    });
  }

  void _showHoldExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151D30),
        title: const Text(
          'Hold Expired',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Your slot reservation hold has expired. Please select a slot again to complete your booking.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _applyPromo() {
    final code = _promoController.text.trim().toUpperCase();
    if (code == 'TURF20') {
      setState(() {
        _discount = widget.slot.price * 0.20; // 20% discount
        _appliedPromo = code;
        _isPromoApplied = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Promo Code TURF20 applied successfully! (20% off)'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid Promo Code'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removePromo() {
    setState(() {
      _discount = 0.0;
      _appliedPromo = null;
      _isPromoApplied = false;
      _promoController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    // Pricing breakdowns
    final double basePrice = widget.slot.price;
    final double discountPrice = basePrice - _discount;
    final double gst = discountPrice * _taxRate;
    final double totalAmount = discountPrice + _convenienceFee + gst;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout Summary'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: MultiBlocListener(
        listeners: [
          // 1. Listening to Booking hold/order statuses
          BlocListener<BookingBloc, BookingState>(
            listener: (context, state) {
              if (state is BookingHoldSuccess) {
                _currentBookingId = state.bookingId;
                _startHoldTimer();

                if (_paymentMethod == 'RAZORPAY') {
                  context.read<BookingBloc>().add(
                    CreateRazorpayOrderRequested(state.bookingId),
                  );
                } else if (_paymentMethod == 'WALLET') {
                  context.read<WalletBloc>().add(
                    PayBookingWithWalletRequested(state.bookingId),
                  );
                }
              }

              if (state is BookingHoldFailure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.error),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              }

              if (state is RazorpayOrderSuccess) {
                _showMockPaymentSheet(context, state.orderId, totalAmount);
              }

              if (state is RazorpayOrderFailure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.error),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              }

              if (state is PaymentSuccess) {
                _countdownTimer?.cancel();
                _showSuccessDialog();
              }
            },
          ),
          // 2. Listening to Wallet transaction status
          BlocListener<WalletBloc, WalletState>(
            listener: (context, state) {
              if (state is WalletLoaded) {
                if (state.actionSuccessMsg == 'PAYMENT_SUCCESS') {
                  context.read<WalletBloc>().add(ClearWalletStatus());
                  context.read<WalletBloc>().add(LoadWallet());
                  _countdownTimer?.cancel();
                  _showSuccessDialog();
                } else if (state.actionError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.actionError!),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                  context.read<WalletBloc>().add(ClearWalletStatus());
                }
              }
            },
          ),
        ],
        child: BlocBuilder<BookingBloc, BookingState>(
          builder: (context, bookingState) {
            return BlocBuilder<WalletBloc, WalletState>(
              builder: (context, walletState) {
                final isBookingLoading =
                    bookingState is BookingHoldLoading ||
                    bookingState is RazorpayOrderLoading;
                final isWalletLoading =
                    walletState is WalletLoaded &&
                    walletState.isActionInProgress;
                final isLoading = isBookingLoading || isWalletLoading;

                double walletBalance = 0.0;
                if (walletState is WalletLoaded) {
                  walletBalance = walletState.wallet.balance;
                }

                final isWalletInsufficient = walletBalance < totalAmount;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hold timer warning banner if active
                      if (_isHolding) _buildHoldTimerBanner(theme),

                      // 1. Turf & Court details card
                      _buildBookingDetailsCard(theme),
                      const SizedBox(height: 20),

                      // 2. Promo Code Selector
                      _buildPromoSection(theme, primaryColor),
                      const SizedBox(height: 20),

                      // 3. Select Payment Method Selector
                      Text(
                        'Select Payment Method',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPaymentMethodSelector(
                        theme,
                        primaryColor,
                        walletBalance,
                        totalAmount,
                        isWalletInsufficient,
                      ),
                      const SizedBox(height: 20),

                      // 4. Fee Breakdown list
                      _buildPaymentBreakdownCard(
                        theme,
                        basePrice,
                        gst,
                        totalAmount,
                      ),
                      const SizedBox(height: 32),

                      // 5. Submit CTA Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              (isLoading || _secondsRemaining <= 0)
                              ? null
                              : () {
                                  // Hold slot first
                                  context.read<BookingBloc>().add(
                                    HoldSlotRequested(
                                      widget.slotId,
                                      offerCode: _appliedPromo,
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.black,
                                )
                              : Text(
                                  _paymentMethod == 'WALLET'
                                      ? 'Pay via Turf Wallet'
                                      : 'Proceed to Payment',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHoldTimerBanner(ThemeData theme) {
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Holding slot for $minutes:$seconds minutes. Complete payment before expiration.',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingDetailsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.turf.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.turf.address,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const Divider(height: 24, color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pitch/Court:',
                  style: TextStyle(color: Colors.white60),
                ),
                Text(
                  widget.turf.courts
                      .firstWhere((c) => c.id == widget.slot.courtId)
                      .name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Date:', style: TextStyle(color: Colors.white60)),
                Text(
                  widget.slot.date,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Time Slot:',
                  style: TextStyle(color: Colors.white60),
                ),
                Text(
                  '${widget.slot.startTime} - ${widget.slot.endTime}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoSection(ThemeData theme, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151D30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Have a Promo Code?',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoController,
                  enabled: !_isPromoApplied,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Enter code (e.g. TURF20)',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isPromoApplied ? _removePromo : _applyPromo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPromoApplied ? Colors.red : primaryColor,
                  foregroundColor: _isPromoApplied
                      ? Colors.white
                      : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _isPromoApplied ? 'Remove' : 'Apply',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector(
    ThemeData theme,
    Color primaryColor,
    double walletBalance,
    double totalAmount,
    bool isWalletInsufficient,
  ) {
    return Column(
      children: [
        // 1. Razorpay Option
        _buildPaymentMethodOption(
          theme: theme,
          primaryColor: primaryColor,
          value: 'RAZORPAY',
          title: 'Razorpay Checkout (UPI, Cards)',
          subtitle: 'Instant secure payments gateway',
          icon: Icons.payment,
        ),
        const SizedBox(height: 10),
        // 2. Wallet Option
        _buildPaymentMethodOption(
          theme: theme,
          primaryColor: primaryColor,
          value: 'WALLET',
          title: 'Turf Wallet',
          subtitle: isWalletInsufficient
              ? 'Insufficient balance (Current: ₹${walletBalance.toInt()})'
              : 'Fastest checkouts (Current: ₹${walletBalance.toInt()})',
          icon: Icons.account_balance_wallet,
          disabled: isWalletInsufficient,
        ),
      ],
    );
  }

  Widget _buildPaymentMethodOption({
    required ThemeData theme,
    required Color primaryColor,
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    bool disabled = false,
  }) {
    final isSelected = _paymentMethod == value;

    return GestureDetector(
      onTap: disabled
          ? null
          : () {
              setState(() {
                _paymentMethod = value;
              });
            },
      child: Container(
        decoration: BoxDecoration(
          color: disabled
              ? Colors.white.withOpacity(0.01)
              : const Color(0xFF151D30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.white10,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              color: disabled
                  ? Colors.white24
                  : (isSelected ? primaryColor : Colors.white60),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: disabled ? Colors.white30 : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: disabled
                          ? Colors.redAccent.withOpacity(0.5)
                          : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentBreakdownCard(
    ThemeData theme,
    double base,
    double gst,
    double total,
  ) {
    final primaryColor = theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bill Details',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Court Price',
                  style: TextStyle(color: Colors.white60),
                ),
                Text(
                  '₹${base.toInt()}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            if (_isPromoApplied) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Promo Discount',
                    style: TextStyle(color: Colors.green),
                  ),
                  Text(
                    '-₹${_discount.toInt()}',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Convenience Fee',
                  style: TextStyle(color: Colors.white60),
                ),
                Text(
                  '₹${_convenienceFee.toInt()}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GST (18%)',
                  style: TextStyle(color: Colors.white60),
                ),
                Text(
                  '₹${gst.toInt()}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Payable Amount',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '₹${total.toInt()}',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMockPaymentSheet(
    BuildContext context,
    String orderId,
    double totalAmount,
  ) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF151D30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Razorpay Payment Sheet',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Order ID: $orderId',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'Amount: ₹${totalAmount.toInt()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment cancelled by user'), backgroundColor: Colors.red),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        // Trigger Razorpay payment mock completion
                        context.read<BookingBloc>().add(PaymentCompleted());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Pay (Mock success)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF151D30),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('Booking Confirmed!', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            'Your pitch booking has been successfully confirmed. You can see your reservation ticket in your Bookings tab.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.black,
              ),
              child: const Text(
                'View Ticket',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
