import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

void main() => runApp(const MyApp());

class SensorData {
  final DateTime timestamp;
  final double temperature;
  final double humidity;

  SensorData({
    required this.timestamp,
    required this.temperature,
    required this.humidity,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    final createdAtString = json['create_at'] ?? json['timestamp'];
    DateTime timestamp;
    if (createdAtString is String) {
      timestamp = DateTime.tryParse(createdAtString) ?? DateTime.now();
    } else if (json['timestamp'] is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(json['timestamp']);
    } else {
      timestamp = DateTime.now(); // Fallback to current time if parsing fails
    }

    return SensorData(
      timestamp: timestamp,
      temperature: double.parse(json['temperature'].toString()),
      humidity: double.parse(json['humidity'].toString()),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensor Dashboard',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey.shade100,
        fontFamily: 'Noto Sans',
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 18),
        ),
      ),
      home: const DashboardPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DashboardPage extends StatefulWidget {
  final http.Client? httpClient;

  const DashboardPage({super.key, this.httpClient});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<SensorData> sensorDataList = [];
  bool isLoading = false;

  Future<void> fetchSensorData() async {
    setState(() => isLoading = true);
    final client = widget.httpClient ?? http.Client();

    // <-- REPLACE THIS URL with your own backend API endpoint without credentials!
    final url = Uri.parse(
      'https://your-backend-api-url.com/api/sensor-data?device_id=1',
    );

    try {
      final response =
          await client.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        debugPrint(jsonData.toString()); // optional for debugging

        if (jsonData['status'] == 'success' && jsonData['data'] is List) {
          final List<dynamic> dataList = jsonData['data'];

          setState(() {
            sensorDataList =
                dataList.map((json) => SensorData.fromJson(json)).toList();
            isLoading = false;
          });
        } else {
          throw Exception('Invalid data format received from server');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on TimeoutException {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request timed out. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching data: $e'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Error fetching data: $e');
    } finally {
      client.close();
    }
  }

  @override
  void initState() {
    super.initState();
    fetchSensorData();
  }

  @override
  Widget build(BuildContext context) {
    final latest = sensorDataList.isNotEmpty ? sensorDataList.last : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Dashboard'),
        backgroundColor: Colors.deepPurple,
        elevation: 5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (latest != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCard(
                      'Temperature',
                      '${latest.temperature.toStringAsFixed(1)} °C',
                      Colors.orange),
                  _buildCard('Humidity',
                      '${latest.humidity.toStringAsFixed(1)} %', Colors.blue),
                  _buildCard(
                    'Relay',
                    latest.temperature > 30 ? 'ON' : 'OFF',
                    latest.temperature > 30 ? Colors.red : Colors.green,
                  ),
                ],
              ),
            const SizedBox(height: 20),
            Text(
              latest != null
                  ? 'Last Updated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(latest.timestamp)}'
                  : 'Fetching data...',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: isLoading ? null : fetchSensorData,
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh"),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6)
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: AxisTitles(),
                        bottomTitles: AxisTitles(),
                        rightTitles: AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(value.toStringAsFixed(
                                  1)); // Display value with one decimal place
                            },
                            reservedSize: 40, // Reserve space for labels
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        // Temperature Line
                        LineChartBarData(
                          spots: sensorDataList.asMap().entries.map((entry) {
                            int index = entry.key;
                            final data = entry.value;
                            return FlSpot(index.toDouble(), data.temperature);
                          }).toList(),
                          isCurved: true,
                          color: Colors.orange,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(show: false),
                        ),

                        // Humidity Line
                        LineChartBarData(
                          spots: sensorDataList.asMap().entries.map((entry) {
                            int index = entry.key;
                            final data = entry.value;
                            return FlSpot(index.toDouble(), data.humidity);
                          }).toList(),
                          isCurved: true,
                          color: Colors.blue,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, String value, Color color) {
    return Card(
      elevation: 4,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 150,
        height: 100,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16)),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 22)),
          ],
        ),
      ),
    );
  }
}
