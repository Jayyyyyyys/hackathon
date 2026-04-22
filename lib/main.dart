import 'package:flutter/material.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

// ─── INITIALIZATION ──────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jslvrfdgyrayxaazqqce.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpzbHZyZmRneXJheXhhYXpxcWNlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY2NjA2NzMsImV4cCI6MjA5MjIzNjY3M30.E37Wf6JAjrVcua_x8iOWIbDwwsbO4w005-0mPKFzCpI',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'University PWD Map',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D9E75)),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

// ─── DATA MODELS ──────────────────────────────────────────────────────────────

class BuildingHitbox {
  final String name;
  final Rect area; // Percentage area of the building on the map image
  final Offset markerPos; // Where the "!" exclamation mark appears
  const BuildingHitbox({required this.name, required this.area, required this.markerPos});
}

class PWDReport {
  final String? id;
  final String buildingName;
  final int floor;
  final String room;
  final String description;
  final String status; // 'ongoing' or 'resolved'
  final String? imageUrl;

  const PWDReport({
    this.id, required this.buildingName, required this.floor, 
    required this.room, required this.description, 
    this.status = 'ongoing', this.imageUrl
  });

  static PWDReport fromMap(Map<String, dynamic> m) => PWDReport(
    id: m['id'].toString(),
    buildingName: m['building_name'] ?? 'Unknown',
    floor: m['floor'] ?? 1,
    room: m['location'] ?? 'Room',
    description: m['description'] ?? '',
    status: m['status'] ?? 'ongoing',
    imageUrl: m['image_url'],
  );
}

// ─── CAMPUS CONFIGURATION (HITBOXES) ─────────────────────────────────────────

// TEACHING POINT: How to make a hitbox
// Rect.fromLTRB(Left, Top, Right, Bottom) - values from 0.0 to 1.0
final List<BuildingHitbox> kBuildings = [
  BuildingHitbox(
    name: "CICS Building",
    area: const Rect.fromLTRB(0.1, 0.2, 0.4, 0.5), // Top Left quadrant
    markerPos: const Offset(0.25, 0.35),
  ),
  BuildingHitbox(
    name: "Library",
    area: const Rect.fromLTRB(0.5, 0.5, 0.8, 0.8), // Bottom Right quadrant
    markerPos: const Offset(0.65, 0.65),
  ),
];

// ─── MAIN SCREEN ──────────────────────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String? _selectedBuilding;
  final _supabase = Supabase.instance.client;

  // Stream for all reports to handle the Exclamation marks on the main map
  Stream<List<PWDReport>> get _allReportsStream => 
      _supabase.from('reports').stream(primaryKey: ['id']).map((data) => data.map((m) => PWDReport.fromMap(m)).toList());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedBuilding ?? 'Campus Accessibility Map'),
        leading: _selectedBuilding != null 
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedBuilding = null)) 
          : null,
      ),
      body: StreamBuilder<List<PWDReport>>(
        stream: _allReportsStream,
        builder: (context, snapshot) {
          final reports = snapshot.data ?? [];
          
          if (_selectedBuilding == null) {
            return _buildCampusMapView(reports);
          } else {
            return _buildBuildingView(reports);
          }
        }
      ),
    );
  }

// ─── VIEW 1: CAMPUS IMAGE WITH HITBOXES ───
  // ─── VIEW 1: CAMPUS IMAGE WITH HITBOXES ───
  Widget _buildCampusMapView(List<PWDReport> reports) {
    return LayoutBuilder(builder: (context, constraints) {
      // These variables (w and h) are needed for the math in your print statement
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      return Stack(
        children: [
          // 1. YOUR ACTUAL UNIVERSITY MAP IMAGE
          Image.asset(
            'assets/images/campus_map.jpg', 
            width: w, 
            height: h, 
            fit: BoxFit.contain, 
          ),

          // 2. GENERATE HITBOXES AND "!" ICONS
          for (var building in kBuildings) ...[
            // THIS IS WHERE YOU PUT THE GESTURE DETECTOR
            Positioned(
              left: building.area.left * w, 
              top: building.area.top * h,
              width: building.area.width * w, 
              height: building.area.height * h,
              child: GestureDetector(
                // COORDINATE FINDER: Check coordinates of taps within the hitbox
                onTapDown: (details) {
                  double tappedX = details.localPosition.dx / (building.area.width * w);
                  double tappedY = details.localPosition.dy / (building.area.height * h);
                  
                  // This tells you the coordinates relative to the WHOLE screen
                  print("Building: ${building.name}");
                  print("Clicked Percent -> X: ${details.globalPosition.dx / w}, Y: ${details.globalPosition.dy / h}");
                },
                onTap: () => setState(() => _selectedBuilding = building.name),
                // DEBUG COLOR: This makes the hitbox red so you can see if it's in the right place
                child: Container(
                  color: Colors.red.withOpacity(0.3), 
                  child: Center(child: Text(building.name, style: const TextStyle(fontSize: 10, color: Colors.white))),
                ),
              ),
            ),
            
            // Exclamation Mark
            if (reports.any((r) => r.buildingName == building.name && r.status == 'ongoing'))
              Positioned(
                left: building.markerPos.dx * w - 15, 
                top: building.markerPos.dy * h - 15,
                child: const Icon(Icons.error, color: Colors.red, size: 35),
              ),
          ],
        ],
      );
    });
  }

  // ─── VIEW 2: BUILDING INTERIOR (Floors/Rooms) ───
  Widget _buildBuildingView(List<PWDReport> reports) {
    return ListView.builder(
      itemCount: 5, // 5 Floors
      itemBuilder: (ctx, f) {
        int floor = f + 1;
        return ExpansionTile(
          title: Text("Floor $floor"),
          children: List.generate(6, (r) { // 6 Rooms
            int roomNum = r + 1;
            String roomName = "Room $roomNum";
            
            // Find if this specific room has a report
            final report = reports.firstWhere(
              (rep) => rep.buildingName == _selectedBuilding && rep.floor == floor && rep.room == roomName,
              orElse: () => const PWDReport(buildingName: '', floor: 0, room: '', description: ''),
            );

            return ListTile(
              leading: Icon(
                report.room.isEmpty ? Icons.add_circle_outline : Icons.report_problem,
                color: report.room.isEmpty ? Colors.grey : (report.status == 'ongoing' ? Colors.red : Colors.green),
              ),
              title: Text(roomName),
              subtitle: Text(report.room.isEmpty ? "No issues reported" : "Status: ${report.status}"),
              onTap: () => _handleRoomAction(floor, roomName, report),
            );
          }),
        );
      },
    );
  }

  void _handleRoomAction(int floor, String room, PWDReport report) {
    if (report.room.isNotEmpty) {
      _showReportCard(report);
    } else {
      _showSubmitDialog(floor, room);
    }
  }

  // ─── VIEW 3: REPORT CARD ───
  void _showReportCard(PWDReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (report.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(report.imageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 15),
            Text("${report.buildingName} - ${report.room}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text("Floor: ${report.floor}", style: const TextStyle(fontSize: 16)),
            const Divider(),
            const Text("Description:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(report.description),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text("Status: "),
                Text(report.status.toUpperCase(), style: TextStyle(color: report.status == 'ongoing' ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── VIEW 4: SUBMIT FORM ───
  // ─── VIEW 4: SUBMIT FORM (UPDATED FOR WEB) ───
  void _showSubmitDialog(int floor, String room) {
    final picker = ImagePicker();
    Uint8List? imageBytes; 
    XFile? pickedFile;
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text("Report Issue at $room"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    // 1. Pick the image
                    final img = await picker.pickImage(source: ImageSource.gallery);
                    
                    if (img != null) {
                      // 2. Immediately read the bytes (This fixes the Web freeze)
                      final bytes = await img.readAsBytes();
                      
                      // 3. Update the dialog state
                      setDlgState(() {
                        pickedFile = img;
                        imageBytes = bytes;
                      });
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: imageBytes == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                              Text("Click to select photo", style: TextStyle(color: Colors.grey)),
                            ],
                          )
                        // USE Image.memory for a reliable web preview
                        : Image.memory(imageBytes!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: "Describe the issue"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                // 1. Check if description is empty
                if (descCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text("Please add a description")),
                  );
                  return;
                }

                // 2. Show a loading circle
                showDialog(
                  context: ctx,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  String? publicUrl;
                  
                  // 3. Handle Image Upload if an image was picked
                  if (imageBytes != null && pickedFile != null) {
                    final fileName = 'report_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    await _supabase.storage.from('report-image').uploadBinary(
                          fileName,
                          imageBytes!,
                          fileOptions: const FileOptions(contentType: 'image/jpeg'),
                        );
                    publicUrl = _supabase.storage.from('report-images').getPublicUrl(fileName);
                  }

                  // 4. Insert the report into the Database
                  await _supabase.from('reports').insert({
                    'building_name': _selectedBuilding,
                    'floor': floor,
                    'location': room,
                    'description': descCtrl.text,
                    'status': 'ongoing',
                    'image_url': publicUrl,
                    'issue_type': 'Accessibility',
                    'severity': 'medium',
                    'x_norm': 0,
                  });

                  // 5. Success: Close loading circle and dialog
                  if (ctx.mounted) {
                    Navigator.pop(ctx); // Close loading circle
                    Navigator.pop(ctx); // Close submission dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Report Submitted Successfully!")),
                    );
                  }
                } catch (e) {
                  // 6. Error: Close loading circle and show error popup
                  if (ctx.mounted) {
                    Navigator.pop(ctx); // Close loading circle
                    showDialog(
                      context: ctx,
                      builder: (context) => AlertDialog(
                        title: const Text("Submit Failed"),
                        content: Text(e.toString()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("OK"),
                          )
                        ],
                      ),
                    );
                  }
                }
              },
              child: const Text("Submit"),
            )
          ],
        ),
      ),
    );
  }
}