class WalletTransaction {
  final String id;
  final String type; // WALLET_CREDIT, BOOKING_CHARGE, BOOKING_REFUND
  final double amount;
  final String? description;
  final String? bookingId;
  final String createdAt;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.description,
    this.bookingId,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      bookingId: json['bookingId'] as String?,
      createdAt: json['createdAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'description': description,
      'bookingId': bookingId,
      'createdAt': createdAt,
    };
  }
}

class Wallet {
  final String id;
  final String userId;
  final double balance;
  final List<WalletTransaction> transactions;

  Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.transactions,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      userId: json['userId'] as String,
      balance: (json['balance'] as num).toDouble(),
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'balance': balance,
      'transactions': transactions.map((e) => e.toJson()).toList(),
    };
  }
}
