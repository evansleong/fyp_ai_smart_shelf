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
  late Future<List<dynamic>> _transactionsFuture;
  
  // Filter state
  List<String> _selectedPaymentTypes = [];
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedDateRangePreset;
  
  // Available payment types (will be extracted from transactions)
  Set<String> _availablePaymentTypes = {};

  @override
  void initState() {
    super.initState();
    _transactionsFuture =
        _apiService.getCustomerOrdersHistory(widget.shpUserId);
    
    // Set default date range to last 30 days
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _selectedDateRangePreset = 'Last 30 days';
  }

  List<dynamic> _filterTransactions(List<dynamic> transactions) {
    // Extract available payment types
    _availablePaymentTypes = transactions
        .map((t) => (t['payment_method'] ?? 'Card').toString())
        .toSet();
    
    List<dynamic> filtered = transactions;
    
    // Filter by date range (only if both dates are set)
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
          
          // Set time to start of day for startDate and end of day for endDate
          final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
          final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
          
          return transactionDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
                 transactionDate.isBefore(end.add(const Duration(seconds: 1)));
        } catch (e) {
          return false;
        }
      }).toList();
    }
    
    // Filter by payment type
    if (_selectedPaymentTypes.isNotEmpty) {
      filtered = filtered.where((transaction) {
        final paymentMethod = (transaction['payment_method'] ?? 'Card').toString();
        return _selectedPaymentTypes.contains(paymentMethod);
      }).toList();
    }
    
    return filtered;
  }

  String _getDateRangeDisplay() {
    if (_startDate == null || _endDate == null) {
      return 'All transactions';
    }
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
        title: const Text(
          'Transaction History',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Column(
        children: [
          // Date range display bar
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
                        const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Color(0xFF1E293B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getDateRangeDisplay(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF1E293B),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: _showFilterBottomSheet,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFF1E293B),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Transaction list
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6366F1),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load history',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No transactions yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your transaction history will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          final allTransactions = snapshot.data!;
          
          // Filter transactions
          final transactions = _filterTransactions(allTransactions);
          
          transactions.sort((a, b) {
            try {
              final String aDateStr = a['date'] ?? '';
              final String aTimeStr = a['time'] ?? '';
              final inputFormat = DateFormat('yyyy-MM-dd hh:mm a');
              final DateTime aDateTime =
                  inputFormat.parse('$aDateStr $aTimeStr');

              final String bDateStr = b['date'] ?? '';
              final String bTimeStr = b['time'] ?? '';
              final DateTime bDateTime =
                  inputFormat.parse('$bDateStr $bTimeStr');

              return bDateTime.compareTo(aDateTime);
            } catch (e) {
              return 0;
            }
          });

          final List<dynamic> groupedItems = [];
          String? currentMonthHeader;
          final DateFormat headerFormat = DateFormat('MMMM yyyy');

          for (final transaction in transactions) {
            final String dateString = transaction['date'] ?? '';
            String monthHeader = "UNKNOWN MONTH";
            try {
              final DateTime date = DateTime.parse(dateString);
              monthHeader = headerFormat.format(date);
            } catch (e) {
              if (dateString.isNotEmpty) {
                monthHeader = dateString;
              }
            }

            if (monthHeader != currentMonthHeader) {
              currentMonthHeader = monthHeader;
              groupedItems.add(monthHeader);
            }
            groupedItems.add(transaction);
          }

          return ListView.builder(
            itemCount: groupedItems.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final item = groupedItems[index];

              if (item is String) {
                return _buildMonthHeader(item);
              }

              if (item is Map<String, dynamic>) {
                return _buildTransactionCard(item, context);
              }
              return const SizedBox.shrink();
            },
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
      child: Text(
        month,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction, BuildContext context) {
    double amount = 0.0;
    if (transaction['amount'] != null) {
      amount = double.tryParse(transaction['amount'].toString()) ?? 0.0;
    }
    final String displayAmount = 'RM ${amount.abs().toStringAsFixed(2)}';
    
    final paymentMethod = transaction['payment_method'] ?? 'Card';
    final shopName = transaction['shop_name'] ?? transaction['details'] ?? 'Purchase';
    
    final String dateStr = transaction['date'] ?? '';
    final String timeStr = transaction['time'] ?? '';
    String displayDate = '';
    String displayTime = '';

    if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
      try {
        final inputFormat = DateFormat('yyyy-MM-dd hh:mm a');
        final dateTimeFormat = DateFormat('dd MMM yyyy');
        final timeFormat = DateFormat('hh:mm a');
        final DateTime parsedDateTime = inputFormat.parse('$dateStr $timeStr');
        displayDate = dateTimeFormat.format(parsedDateTime);
        displayTime = timeFormat.format(parsedDateTime);
      } catch (e) {
        displayDate = dateStr;
        displayTime = timeStr;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TransactionDetailsScreen(
                  transaction: transaction,
                ),
              ),
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
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Color(0xFF6366F1),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (displayDate.isNotEmpty) ...[
                            Text(
                              displayDate,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              ' • ',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                          Text(
                            displayTime.isNotEmpty ? displayTime : paymentMethod,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      displayAmount,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        paymentMethod,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
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
        selectedPaymentTypes: _selectedPaymentTypes,
        onPaymentTypesChanged: (selected) {
          setState(() {
            _selectedPaymentTypes = selected;
          });
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
        end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
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
        _tempPreset = null; // Custom range
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
        _tempEndDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        _tempPreset = null; // Custom range
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
                // Preset options in grid layout
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
                // Custom date range
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
                                    ? DateFormat('dd MMM yy').format(_tempStartDate!)
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
                                    ? DateFormat('dd MMM yy').format(_tempEndDate!)
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
                  widget.onDateRangeSelected(_tempStartDate, _tempEndDate, _tempPreset);
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
        width: (MediaQuery.of(context).size.width - 64) / 2, // Fixed width: (screen width - padding) / 2
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          preset,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? const Color(0xFF6366F1)
                : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }
}

class _FilterBottomSheet extends StatefulWidget {
  final List<String> availablePaymentTypes;
  final List<String> selectedPaymentTypes;
  final Function(List<String>) onPaymentTypesChanged;

  const _FilterBottomSheet({
    required this.availablePaymentTypes,
    required this.selectedPaymentTypes,
    required this.onPaymentTypesChanged,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late List<String> _tempSelectedTypes;

  @override
  void initState() {
    super.initState();
    _tempSelectedTypes = List.from(widget.selectedPaymentTypes);
  }

  void _togglePaymentType(String type) {
    setState(() {
      if (_tempSelectedTypes.contains(type)) {
        _tempSelectedTypes.remove(type);
      } else {
        _tempSelectedTypes.add(type);
      }
    });
  }

  void _clearAll() {
    setState(() {
      _tempSelectedTypes.clear();
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
          // Clear all button
          if (_tempSelectedTypes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _clearAll,
                  child: const Text(
                    'Clear all',
                    style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
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
              final isSelected = _tempSelectedTypes.contains(type);
              return InkWell(
                onTap: () => _togglePaymentType(type),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: isSelected
                            ? const Color(0xFF6366F1)
                            : Colors.grey.shade400,
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
                  widget.onPaymentTypesChanged(_tempSelectedTypes);
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