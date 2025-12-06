import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/services/api_service.dart';
import 'transaction_details_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final String shpUserId;

  const TransactionHistoryScreen({
    super.key,
    required this.shpUserId,
  });

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _allTransactions = [];
  List<dynamic> _filteredTransactions = [];
  Map<String, int> _pointsMap = {};
  Map<String, int> _pointsByOrderId = {};
  String? _selectedPaymentType;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedDateRangePreset;
  Set<String> _availablePaymentTypes = {};

  @override
  void initState() {
    super.initState();
    // Default date range
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _selectedDateRangePreset = 'Last 30 days';

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch Orders and Points in parallel
      final results = await Future.wait([
        _apiService.getCustomerOrdersHistory(widget.shpUserId),
        _apiService.getPointsHistory(widget.shpUserId),
      ]);

      final orders = results[0];
      final pointsHistory = results[1];

      print("DEBUG: Orders Found: ${orders.length}");
      print("DEBUG: Points History Found: ${pointsHistory.length}");

      // 2. Build the Points Map from the Table Data
      final Map<String, int> pointsByOrderId = {};

      for (var p in pointsHistory) {
        final rawPoints = p['points_earned'];
        int pts = 0;

        if (rawPoints is int) {
          pts = rawPoints;
        } else if (rawPoints is String) {
          pts = int.tryParse(rawPoints) ?? 0;
        } else if (rawPoints is Map && rawPoints.containsKey('N')) {
          pts = int.tryParse(rawPoints['N'].toString()) ?? 0;
        }

        String? oId = p['order_id']?.toString();

        if (oId != null && pts > 0) {
          pointsByOrderId[oId] = pts;
        }
      }

      _pointsByOrderId = pointsByOrderId;

      print(
          "DEBUG: Final Points Map Created with ${pointsByOrderId.length} entries.");
      if (pointsByOrderId.isNotEmpty) {
        print(
            "DEBUG: Map Keys (first 5): ${pointsByOrderId.keys.take(5).toList()}");
      }

      if (orders.isNotEmpty) {
        print("DEBUG: All fields in first transaction:");
        final firstTransaction = orders[0];
        firstTransaction.keys.forEach((key) {
          print("  $key: ${firstTransaction[key]}");
        });
        print("DEBUG: Looking for order ID field...");
      }

      // 3. Try to match orders with points by fetching full order details
      try {
        final fullOrders =
            await _apiService.getCustomerOrders(widget.shpUserId);

        print("DEBUG: Full orders fetched: ${fullOrders.length}");
        if (fullOrders.isNotEmpty) {
          print("DEBUG: First full order keys: ${fullOrders[0].keys.toList()}");
        }

        final Map<String, String> compositeKeyToOrderId = {};
        for (var order in fullOrders) {
          final orderId =
              order['order_id']?.toString() ?? order['orderId']?.toString();
          if (orderId != null) {
            final createdAt = order['created_at']?.toString() ?? '';
            final summary = order['summary'];
            double? totalPrice;
            if (summary != null && summary['total_price'] != null) {
              final tp = summary['total_price'];
              if (tp is num) {
                totalPrice = tp.toDouble();
              } else if (tp is Map && tp.containsKey('N')) {
                totalPrice = double.tryParse(tp['N'].toString());
              } else if (tp is String) {
                totalPrice = double.tryParse(tp);
              }
            }

            if (createdAt.isNotEmpty && totalPrice != null) {
              try {
                final dateTime = DateTime.parse(createdAt);
                final dateStr = dateTime.toIso8601String().split('T')[0];
                final amountStr = totalPrice.toStringAsFixed(2);
                final compositeKey = '$dateStr|$amountStr';
                compositeKeyToOrderId[compositeKey] = orderId;
                print(
                    "DEBUG: Mapped key '$compositeKey' -> order_id '$orderId'");
              } catch (e) {
                print(
                    "DEBUG: Error parsing order date: $e, createdAt: $createdAt");
              }
            }
          }
        }

        print("DEBUG: Composite key map size: ${compositeKeyToOrderId.length}");

        final Map<String, int> finalPointsMap = {};
        int matchedCount = 0;
        for (var transaction in orders) {
          final dateStr = transaction['date']?.toString() ?? '';
          final amountStr = transaction['amount']?.toString() ?? '';

          if (dateStr.isNotEmpty && amountStr.isNotEmpty) {
            try {
              final normalizedDate = dateStr;
              final normalizedAmount =
                  double.tryParse(amountStr)?.toStringAsFixed(2) ?? amountStr;

              final compositeKey = '$normalizedDate|$normalizedAmount';
              final orderId = compositeKeyToOrderId[compositeKey];

              if (orderId != null && _pointsByOrderId.containsKey(orderId)) {
                finalPointsMap[compositeKey] = _pointsByOrderId[orderId]!;
                matchedCount++;
                print(
                    "DEBUG: Matched transaction '$compositeKey' -> order_id '$orderId' -> ${_pointsByOrderId[orderId]} points");
              } else {
                print(
                    "DEBUG: No match for transaction '$compositeKey' (orderId: $orderId, hasPoints: ${orderId != null && _pointsByOrderId.containsKey(orderId)})");
              }
            } catch (e) {
              print("DEBUG: Error processing transaction: $e");
            }
          }
        }

        print(
            "DEBUG: Final points map size: ${finalPointsMap.length}, Matched: $matchedCount");

        if (mounted) {
          setState(() {
            _allTransactions = orders;
            _pointsMap = finalPointsMap;
            _filterTransactions();
            _isLoading = false;
          });
        }
      } catch (e) {
        print("DEBUG: Error matching orders with points: $e");
        if (mounted) {
          setState(() {
            _allTransactions = orders;
            _pointsMap = {};
            _filterTransactions();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("DEBUG: Error loading data: $e");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _filterTransactions() {
    _availablePaymentTypes = _allTransactions
        .map((t) => (t['payment_method'] ?? 'Card').toString())
        .toSet();

    List<dynamic> filtered = List.from(_allTransactions);

    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((transaction) {
        final String dateStr = transaction['date'] ?? '';
        final String timeStr = transaction['time'] ?? '';
        if (dateStr.isEmpty) return false;

        try {
          final inputFormat = DateFormat('yyyy-MM-dd hh:mm a');
          DateTime transactionDate;
          if (timeStr.isNotEmpty) {
            transactionDate = inputFormat.parse('$dateStr $timeStr');
          } else {
            transactionDate = DateTime.parse(dateStr);
          }

          final start =
              DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
          final end = DateTime(
              _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);

          return transactionDate
                  .isAfter(start.subtract(const Duration(seconds: 1))) &&
              transactionDate.isBefore(end.add(const Duration(seconds: 1)));
        } catch (e) {
          return false;
        }
      }).toList();
    }

    if (_selectedPaymentType != null && _selectedPaymentType!.isNotEmpty) {
      filtered = filtered.where((transaction) {
        final paymentMethod =
            (transaction['payment_method'] ?? 'Card').toString();
        return paymentMethod == _selectedPaymentType;
      }).toList();
    }

    // Sort Descending
    filtered.sort((a, b) {
      try {
        final String aDateStr = a['date'] ?? '';
        final String aTimeStr = a['time'] ?? '';
        final inputFormat = DateFormat('yyyy-MM-dd hh:mm a');
        final DateTime aDateTime = inputFormat.parse('$aDateStr $aTimeStr');

        final String bDateStr = b['date'] ?? '';
        final String bTimeStr = b['time'] ?? '';
        final DateTime bDateTime = inputFormat.parse('$bDateStr $bTimeStr');
        return bDateTime.compareTo(aDateTime);
      } catch (e) {
        return 0;
      }
    });

    setState(() {
      _filteredTransactions = filtered;
    });
  }

  String _getDateRangeDisplay() {
    if (_startDate == null || _endDate == null) return 'All transactions';
    final dateFormat = DateFormat('dd MMM yy');
    return '${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('Transaction History',
            style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _showDateRangeBottomSheet,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 18, color: Color(0xFF1E293B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_getDateRangeDisplay(),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1E293B))),
                        ),
                        const Icon(Icons.arrow_drop_down,
                            color: Color(0xFF1E293B)),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 20, color: Colors.grey.shade400),
                const SizedBox(width: 16),
                InkWell(
                  onTap: _showFilterBottomSheet,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Filter',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1E293B))),
                      Icon(Icons.arrow_drop_down, color: Color(0xFF1E293B)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : _filteredTransactions.isEmpty
                        ? const Center(child: Text("No transactions found"))
                        : ListView.builder(
                            itemCount: _filteredTransactions.length +
                                1, // +1 for hacky header grouping
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemBuilder: (context, index) {
                              if (index == _filteredTransactions.length)
                                return const SizedBox.shrink();

                              // Simple grouping logic for display
                              final transaction = _filteredTransactions[index];
                              final String dateString =
                                  transaction['date'] ?? '';
                              String monthHeader = "";

                              // Check if this is the first item of the month
                              bool showHeader = false;
                              try {
                                final DateTime date =
                                    DateTime.parse(dateString);
                                final headerFormat = DateFormat('MMMM yyyy');
                                monthHeader = headerFormat.format(date);

                                if (index == 0) {
                                  showHeader = true;
                                } else {
                                  final prevDate = DateTime.parse(
                                      _filteredTransactions[index - 1]['date']);
                                  if (headerFormat.format(prevDate) !=
                                      monthHeader) {
                                    showHeader = true;
                                  }
                                }
                              } catch (_) {}

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showHeader)
                                    _buildMonthHeader(monthHeader),
                                  _buildTransactionCard(transaction, context),
                                ],
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(String month) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Text(month,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.3)),
    );
  }

  Widget _buildTransactionCard(
      Map<String, dynamic> transaction, BuildContext context) {
    // 1. Calculate Amount Paid (Same logic as before)
    double amount = 0.0;
    if (transaction['summary'] != null &&
        transaction['summary']['total_price'] != null) {
      amount =
          double.tryParse(transaction['summary']['total_price'].toString()) ??
              0.0;
    } else if (transaction['amount'] != null) {
      amount = double.tryParse(transaction['amount'].toString()) ?? 0.0;
    }

    // 2. GET REAL POINTS FROM DATABASE MAP
    final String dateStr = transaction['date']?.toString() ?? '';
    final String amountStr = transaction['amount']?.toString() ?? '';

    int pointsEarned = 0;
    if (dateStr.isNotEmpty && amountStr.isNotEmpty) {
      try {
        // Use date + amount only (simpler matching)
        final normalizedDate = dateStr; // Already in YYYY-MM-DD format
        final normalizedAmount =
            double.tryParse(amountStr)?.toStringAsFixed(2) ?? amountStr;

        final compositeKey = '$normalizedDate|$normalizedAmount';
        pointsEarned = _pointsMap[compositeKey] ?? 0;
      } catch (e) {
        // If parsing fails, points remain 0
      }
    }

    final String displayAmount = 'RM ${amount.abs().toStringAsFixed(2)}';
    final paymentMethod = transaction['payment_method'] ?? 'Card';
    final isStolen = paymentMethod.toLowerCase() == 'none';
    final shopName =
        transaction['shop_name'] ?? transaction['details'] ?? 'Purchase';

    // Date formatting for display
    final String displayDateStr = transaction['date']?.toString() ?? '';
    final String displayTimeStr = transaction['time']?.toString() ?? '';
    String displayDate = '';
    String displayTime = '';
    if (displayDateStr.isNotEmpty && displayTimeStr.isNotEmpty) {
      try {
        final inputFormat = DateFormat('yyyy-MM-dd hh:mm a');
        final dateTimeFormat = DateFormat('dd MMM yyyy');
        final timeFormat = DateFormat('hh:mm a');
        final DateTime parsedDateTime =
            inputFormat.parse('$displayDateStr $displayTimeStr');
        displayDate = dateTimeFormat.format(parsedDateTime);
        displayTime = timeFormat.format(parsedDateTime);
      } catch (_) {
        displayDate = displayDateStr;
        displayTime = displayTimeStr;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: isStolen ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isStolen
              ? Border.all(color: Colors.red.shade300, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
                color: isStolen
                    ? Colors.red.withOpacity(0.1)
                    : Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TransactionDetailsScreen(
                        transaction: transaction,
                        shpUserId: widget.shpUserId,
                      )),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: isStolen
                          ? Colors.red.shade100
                          : const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(
                      isStolen
                          ? Icons.warning_amber_rounded
                          : Icons.shopping_bag_outlined,
                      color: isStolen
                          ? Colors.red.shade700
                          : const Color(0xFF6366F1),
                      size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shopName,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (displayDate.isNotEmpty) ...[
                            Text(displayDate,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade600)),
                            Text(' • ',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade400)),
                          ],
                          Text(
                              displayTime.isNotEmpty
                                  ? displayTime
                                  : paymentMethod,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (pointsEarned > 0) ...[
                      Text(
                        '+$pointsEarned pts',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],

                    Text(displayAmount,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isStolen
                                ? Colors.red.shade700
                                : paymentMethod.toLowerCase() == 'points'
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFDC2626))),

                    // Payment method badge (hide for stolen items, show warning instead)
                    const SizedBox(height: 2),
                    if (isStolen)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 12,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text('Missing Items',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade700)),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(paymentMethod,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDateRangeBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DateRangeBottomSheet(
        startDate: _startDate,
        endDate: _endDate,
        selectedPreset: _selectedDateRangePreset,
        onDateRangeSelected: (start, end, preset) {
          setState(() {
            _startDate = start;
            _endDate = end;
            _selectedDateRangePreset = preset;
          });
          _filterTransactions();
        },
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        availablePaymentTypes: _availablePaymentTypes.toList()..sort(),
        selectedPaymentType: _selectedPaymentType,
        onPaymentTypeChanged: (selected) {
          setState(() {
            _selectedPaymentType = selected;
          });
          _filterTransactions();
        },
      ),
    );
  }
}

class _DateRangeBottomSheet extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? selectedPreset;
  final Function(DateTime?, DateTime?, String?) onDateRangeSelected;

  const _DateRangeBottomSheet({
    required this.startDate,
    required this.endDate,
    required this.selectedPreset,
    required this.onDateRangeSelected,
  });

  @override
  State<_DateRangeBottomSheet> createState() => _DateRangeBottomSheetState();
}

class _DateRangeBottomSheetState extends State<_DateRangeBottomSheet> {
  late DateTime? _tempStartDate;
  late DateTime? _tempEndDate;
  late String? _tempPreset;

  @override
  void initState() {
    super.initState();
    _tempStartDate = widget.startDate;
    _tempEndDate = widget.endDate;
    _tempPreset = widget.selectedPreset;
  }

  void _selectPreset(String preset) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (preset) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'Yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day);
        end = DateTime(
            yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case 'Last 7 days':
        start = now.subtract(const Duration(days: 6));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'Last 30 days':
        start = now.subtract(const Duration(days: 29));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'Last 90 days':
        start = now.subtract(const Duration(days: 89));
        start = DateTime(start.year, start.month, start.day);
        break;
    }

    setState(() {
      _tempStartDate = start;
      _tempEndDate = end;
      _tempPreset = preset;
    });
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _tempStartDate = DateTime(picked.year, picked.month, picked.day);
        _tempPreset = null;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempEndDate ?? DateTime.now(),
      firstDate: _tempStartDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _tempEndDate =
            DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        _tempPreset = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Date Range',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Reset button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  widget.onDateRangeSelected(null, null, null);
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.refresh,
                  size: 18,
                  color: Color(0xFF6366F1),
                ),
                label: const Text(
                  'Reset to show all',
                  style: TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildPresetButton('Today'),
                    _buildPresetButton('Yesterday'),
                    _buildPresetButton('Last 7 days'),
                    _buildPresetButton('Last 30 days'),
                    _buildPresetButton('Last 90 days'),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Custom date range',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectStartDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF6366F1),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _tempStartDate != null
                                    ? DateFormat('dd MMM yy')
                                        .format(_tempStartDate!)
                                    : 'Select date',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '-',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectEndDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF6366F1),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _tempEndDate != null
                                    ? DateFormat('dd MMM yy')
                                        .format(_tempEndDate!)
                                    : 'Select date',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Apply button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  widget.onDateRangeSelected(
                      _tempStartDate, _tempEndDate, _tempPreset);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(String preset) {
    final isSelected = _tempPreset == preset;
    return InkWell(
      onTap: () => _selectPreset(preset),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: (MediaQuery.of(context).size.width - 64) / 2,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          preset,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color:
                isSelected ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }
}

class _FilterBottomSheet extends StatefulWidget {
  final List<String> availablePaymentTypes;
  final String? selectedPaymentType;
  final Function(String?) onPaymentTypeChanged;

  const _FilterBottomSheet({
    required this.availablePaymentTypes,
    required this.selectedPaymentType,
    required this.onPaymentTypeChanged,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  String? _tempSelectedType;

  @override
  void initState() {
    super.initState();
    _tempSelectedType = widget.selectedPaymentType;
  }

  void _selectPaymentType(String type) {
    setState(() {
      if (_tempSelectedType == type) {
        _tempSelectedType = null;
      } else {
        _tempSelectedType = type;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter by Payment Type',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Reset button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  widget.onPaymentTypeChanged(null);
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.refresh,
                  size: 18,
                  color: Color(0xFF6366F1),
                ),
                label: const Text(
                  'Reset to show all',
                  style: TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // Payment type list
          if (widget.availablePaymentTypes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                'No payment types available',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            )
          else
            ...widget.availablePaymentTypes.map((type) {
              final isSelected = _tempSelectedType == type;
              return InkWell(
                onTap: () => _selectPaymentType(type),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          type,
                          style: TextStyle(
                            fontSize: 16,
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF1E293B),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Radio<String>(
                        value: type,
                        groupValue: _tempSelectedType,
                        onChanged: (value) => _selectPaymentType(value!),
                        activeColor: const Color(0xFF6366F1),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          // Apply button
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  widget.onPaymentTypeChanged(_tempSelectedType);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
