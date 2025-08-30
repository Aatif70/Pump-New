import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/pricing_repository.dart';
import '../../models/price_model.dart';
import 'dart:developer' as developer;
import 'package:fl_chart/fl_chart.dart';

class FuelPriceHistoryScreen extends StatefulWidget {
  final String fuelType;
  final String? fuelTypeId;
  
  const FuelPriceHistoryScreen({
    Key? key,
    required this.fuelType,
    this.fuelTypeId,
  }) : super(key: key);

  @override
  State<FuelPriceHistoryScreen> createState() => _FuelPriceHistoryScreenState();
}

class _FuelPriceHistoryScreenState extends State<FuelPriceHistoryScreen> {
  final PricingRepository _pricingRepository = PricingRepository();
  
  List<FuelPrice> _priceHistory = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Map of fuel types to their UI colors
  final Map<String, Color> _fuelColors = {
    'Petrol': Colors.green.shade600,
    'Diesel': Colors.blue.shade700,
    'Premium Petrol': Colors.orange.shade600,
    'Premium Diesel': Colors.purple.shade600,
    'CNG': Colors.teal.shade600,
  };
  
  @override
  void initState() {
    super.initState();
    _fetchPriceHistory();
  }
  
  Future<void> _fetchPriceHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      developer.log('FuelPriceHistoryScreen: Fetching price history for ${widget.fuelType}');
      print('DEBUG: Fetching price history for ${widget.fuelType}, fuelTypeId: ${widget.fuelTypeId}');
      
      // Check if fuelTypeId is available
      if (widget.fuelTypeId == null || widget.fuelTypeId!.isEmpty) {
        setState(() {
          _errorMessage = 'Fuel type ID is required for price history';
          _isLoading = false;
          _priceHistory = [];
        });
        
        developer.log('FuelPriceHistoryScreen: Error - Fuel type ID is required');
        print('DEBUG: Error - Fuel type ID is required for price history');
        return;
      }
      
      final response = await _pricingRepository.getPriceHistoryByFuelType(
        widget.fuelType,
        fuelTypeId: widget.fuelTypeId,
      );
      
      if (response.success && response.data != null) {
        // Sort by effective date in descending order (newest first)
        final sortedPrices = response.data!..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
        
        setState(() {
          _priceHistory = sortedPrices;
          _isLoading = false;
        });
        
        developer.log('FuelPriceHistoryScreen: Retrieved ${_priceHistory.length} prices');
        print('DEBUG: Retrieved ${_priceHistory.length} prices for ${widget.fuelType}');
      } else {
        setState(() {
          _errorMessage = response.errorMessage ?? 'Failed to load price history';
          _isLoading = false;
          _priceHistory = [];
        });
        
        developer.log('FuelPriceHistoryScreen: Error getting price history: $_errorMessage');
        print('DEBUG: Error getting price history: $_errorMessage');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
        _priceHistory = [];
      });
      
      developer.log('FuelPriceHistoryScreen: Exception: $e');
      print('DEBUG: Exception in price history screen: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final Color fuelColor = _fuelColors[widget.fuelType] ?? Colors.grey.shade700;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.fuelType} Price History'),
        backgroundColor: fuelColor.withValues(alpha:0.8),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPriceHistory,
            tooltip: 'Refresh Price History',
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
          ? _buildErrorView()
          : _buildHistoryContent(),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchPriceHistory,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHistoryContent() {
    final Color fuelColor = _fuelColors[widget.fuelType] ?? Colors.grey.shade700;
    
    return _priceHistory.isEmpty
      ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No price history available for ${widget.fuelType}',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        )
      : CustomScrollView(
          slivers: [
            // Price trend chart
            if (_priceHistory.length > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Card(
                    elevation: 4,
                    shadowColor: fuelColor.withValues(alpha:0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            fuelColor.withValues(alpha:0.05),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.timeline,
                                    color: fuelColor,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Price Trend',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: fuelColor,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: fuelColor.withValues(alpha:0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_priceHistory.length} Data Points',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: fuelColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(),
                          const SizedBox(height: 8),
                          // Using a fixed but responsive height for the chart area
                          SizedBox(
                            height: 230,
                            child: _buildPriceChart(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
            // Latest price card
            if (_priceHistory.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    elevation: 4,
                    shadowColor: fuelColor.withValues(alpha:0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            fuelColor,
                            fuelColor.withValues(alpha:0.8),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha:0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.local_gas_station,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Current Price',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha:0.25),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('dd MMM').format(_priceHistory.first.effectiveFrom),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${_priceHistory.first.pricePerLiter.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 0.9,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 7),
                                  child: Text(
                                    '/ liter',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_priceHistory.length > 1)
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha:0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _priceHistory.first.pricePerLiter > _priceHistory[1].pricePerLiter
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '₹${(_priceHistory.first.pricePerLiter - _priceHistory[1].pricePerLiter).abs().toStringAsFixed(2)} ${_priceHistory.first.pricePerLiter >= _priceHistory[1].pricePerLiter ? 'increase' : 'decrease'}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            if (_priceHistory.first.lastUpdatedBy != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.person_outline,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Updated by: ${_priceHistory.first.lastUpdatedBy}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
            // Price history section title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 18,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Price History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_priceHistory.length} Entries',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Price history list
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Skip the first item as it's shown in the current price card
                  if (index == 0) return const SizedBox.shrink();
                  
                  final price = _priceHistory[index];
                  return _buildPriceHistoryItem(price, fuelColor, index);
                },
                childCount: _priceHistory.length,
              ),
            ),
            
            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        );
  }
  
  Widget _buildPriceHistoryItem(FuelPrice price, Color color, int index) {
    final bool hasChangeInfo = index > 0 && index < _priceHistory.length - 1;
    final double? priceChange = hasChangeInfo 
        ? price.pricePerLiter - _priceHistory[index + 1].pricePerLiter
        : null;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 2,
        shadowColor: color.withValues(alpha:0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha:0.15), width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                color.withValues(alpha:0.03),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with date and price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Date with icon
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha:0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: color),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd MMM yyyy').format(price.effectiveFrom),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Time
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('HH:mm').format(price.effectiveFrom),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              
              // Price and change info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Price in prominent display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha:0.2)),
                    ),
                    child: Text(
                      '₹${price.pricePerLiter.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  
                  // Price change if available
                  if (priceChange != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: priceChange > 0 
                          ? Colors.red.withValues(alpha:0.1) 
                          : priceChange < 0 
                            ? Colors.green.withValues(alpha:0.1) 
                            : Colors.grey.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: priceChange > 0 
                            ? Colors.red.withValues(alpha:0.3) 
                            : priceChange < 0 
                              ? Colors.green.withValues(alpha:0.3) 
                              : Colors.grey.withValues(alpha:0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            priceChange > 0 
                              ? Icons.arrow_upward 
                              : priceChange < 0 
                                ? Icons.arrow_downward 
                                : Icons.remove,
                            size: 14,
                            color: priceChange > 0 
                              ? Colors.red 
                              : priceChange < 0 
                                ? Colors.green 
                                : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${priceChange > 0 ? '+' : ''}${priceChange.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: priceChange > 0 
                                ? Colors.red 
                                : priceChange < 0 
                                  ? Colors.green 
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              // Updated by info if available
              if (price.lastUpdatedBy != null) 
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          '${price.lastUpdatedBy}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPriceChart() {
    if (_priceHistory.length < 2) {
      return const Center(
        child: Text('Not enough data for chart'),
      );
    }
    
    final Color fuelColor = _fuelColors[widget.fuelType] ?? Colors.grey.shade700;
    
    // First, ensure the prices are sorted by date (oldest to newest)
    final sortedPrices = List<FuelPrice>.from(_priceHistory)
      ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));
    
    // Create chart spots with proper date-based ordering
    // This ensures oldest dates are on the left, newest on the right
    final List<FlSpot> chartData = [];
    for (int i = 0; i < sortedPrices.length; i++) {
      chartData.add(FlSpot(
        i.toDouble(),
        sortedPrices[i].pricePerLiter,
      ));
    }
    
    // Calculate min and max values for the y-axis with some padding
    final prices = _priceHistory.map((p) => p.pricePerLiter).toList();
    final double minY = (prices.reduce((min, p) => p < min ? p : min) * 0.95);
    final double maxY = (prices.reduce((max, p) => p > max ? p : max) * 1.05);
    
    // Helper text for the chart
    final valueRange = maxY - minY;
    final formattedMinY = minY.toStringAsFixed(1);
    final formattedMaxY = maxY.toStringAsFixed(1);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Helper text for price range
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Price range: ₹$formattedMinY - ₹$formattedMaxY',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: valueRange < 1.0
                    ? Colors.green.withValues(alpha:0.1)
                    : valueRange < 5.0
                      ? Colors.amber.withValues(alpha:0.1)
                      : Colors.red.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  valueRange < 1.0
                    ? 'Stable'
                    : valueRange < 5.0
                      ? 'Moderate Change'
                      : 'High Volatility',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: valueRange < 1.0
                      ? Colors.green
                      : valueRange < 5.0
                        ? Colors.amber.shade800
                        : Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // The chart needs to be in an Expanded to avoid overflow
        Flexible(
          child: SizedBox(
            height: 200, // Reduced height to avoid overflow
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) > 0 ? (maxY - minY) / 4 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        // Only show a few strategic labels to avoid crowding
                        final int index = value.toInt();
                        
                        // Show date only at these positions:
                        // - The start (oldest)
                        // - The end (newest/current)
                        // - Potentially at the middle, if there are enough data points
                        bool showLabel = false;
                        
                        if (index == 0) {
                          // First/oldest date
                          showLabel = true;
                        } else if (index == chartData.length - 1) {
                          // Last/newest date
                          showLabel = true;
                        } else if (chartData.length >= 10 && index == (chartData.length ~/ 2)) {
                          // Middle date if we have enough data points
                          showLabel = true;
                        }
                        
                        if (!showLabel || index >= sortedPrices.length) {
                          return const SizedBox.shrink();
                        }
                        
                        // Different formatting for the current/latest date
                        final isLatestDate = index == chartData.length - 1;
                        final date = sortedPrices[index].effectiveFrom;
                        
                        // Simplified label to avoid overflow - use a row instead of column
                        return isLatestDate 
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('dd MMM').format(date),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: fuelColor,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: fuelColor.withValues(alpha:0.1),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    'NOW',
                                    style: TextStyle(
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                      color: fuelColor,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              DateFormat('dd MMM').format(date),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.normal,
                                color: Colors.grey.shade700,
                              ),
                            );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            '₹${value.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                    left: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                minX: 0,
                maxX: chartData.length - 1.0,
                minY: minY,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => fuelColor.withValues(alpha:0.8),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((touchedSpot) {
                        final index = touchedSpot.x.toInt();
                        if (index >= sortedPrices.length) {
                          return null;
                        }
                        
                        final price = sortedPrices[index];
                        final textStyle = const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        );
                        
                        return LineTooltipItem(
                          '₹${touchedSpot.y.toStringAsFixed(2)}',
                          textStyle,
                          children: [
                            TextSpan(
                              text: '\n${DateFormat('dd MMM yyyy, HH:mm').format(price.effectiveFrom)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                  touchSpotThreshold: 20,
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: chartData,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: fuelColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        // Make the most recent dot (rightmost) slightly larger
                        final isLatestPoint = spot.x.toInt() == chartData.length - 1;
                        
                        return FlDotCirclePainter(
                          radius: isLatestPoint ? 6 : 4,
                          color: fuelColor,
                          strokeWidth: isLatestPoint ? 2 : 1,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          fuelColor.withValues(alpha:0.3),
                          fuelColor.withValues(alpha:0.05),
                        ],
                      ),
                    ),
                    shadow: const Shadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
} 