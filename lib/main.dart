import "dart:async";
import "dart:developer";
import "dart:ui";
import "package:path/path.dart";
import "package:sqflite/sqflite.dart";
import "package:path_provider/path_provider.dart";
import 'package:flutter/material.dart';
import "package:flutter_naver_map/flutter_naver_map.dart";
import "dart:io";
import "package:intl/intl.dart";

void main() async {
  await _initialize();
  runApp(MyApp());
}

// String formattedDate = DateFormat('yyyy-MM-dd').format(currentDate);

// 지도 리프레쉬
// 시간 순 새로고침

class DiaryInfo {
  final int? id;
  final double lat;
  final double lng;
  final String title;
  final String date;
  final String content;

  DiaryInfo({this.id, required this.lat, required this.lng, required this.title, required this.date, required this.content});

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "lat": lat,
      "lng": lng,
      "title": title,
      "date": date,
      "content": content
    };
  }
}

class DatabaseHelper {
  static const _databaseName = "Mydatabase.db";
  static const _databaseVersion = 1;
  static const table = "diaries";
  static const columnId = "id";
  static const columnLat = "lat";
  static const columnLng = "lng";
  static const columnTitle = "title";
  static const columnContent = "content";
  static const columnDate = "date";

  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async => _database ??= await _initDatabase();

  Future<Database> _initDatabase() async {
    Directory documentDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentDirectory.path, _databaseName);

    return await openDatabase(path, version: _databaseVersion, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db..execute(
      '''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnLat REAL NOT NULL,
        $columnLng REAL NOT NULL,
        $columnTitle TEXT NOT NULL,
        $columnContent TEXT NOT NULL,
        $columnDate TEXT NOT NULL
      );
    '''
    );
  }

  Future<int> insert(DiaryInfo info) async {
    Database db = await database;
    int id = await db.insert(table, info.toMap());
    return id;
  }

  Future<int> update(DiaryInfo info) async {
    Database db = await database;
    return await db.update(
      table,
      info.toMap(),
      where: "$columnId=?",
      whereArgs: [info.id]
    );
  }

  Future<int> delete(int id) async {
    Database db = await database;
    return await db.delete(
      table,
      where: "$columnId=?",
      whereArgs: [id]
    );
  }

  Future<DiaryInfo> viewInfo(int id) async {
    Database db = await database;
    List<Map> maps = await db.query(
      table,
      where: "id = ?",
      whereArgs: [id]
    );
    DiaryInfo info = DiaryInfo(
      id: maps[0]["id"],
      lat: maps[0]["lat"],
      lng: maps[0]["lng"],
      title: maps[0]["title"],
      content: maps[0]["content"],
      date: maps[0]["date"]
    );
    return info;
  } 

  Future<List<DiaryInfo>> infos() async {
    Database db = await database;
    List<Map> maps = await db.query(table);
    return List.generate(maps.length, (index) {
      return DiaryInfo(
        id: maps[index]["id"],
        lat: maps[index]["lat"],
        lng: maps[index]["lng"],
        date: maps[index]["date"],
        title: maps[index]["title"],
        content: maps[index]["content"]
      );
    });
  }
}

Future<void> _initialize() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NaverMapSdk.instance.initialize(clientId: "kzkbajpzzx", onAuthFailed: (e) => log("네이버맵 인증오류: $e", name: "onAuthFailed"));
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final Completer<NaverMapController> mapControllerCompleter = Completer();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: OnMapScreen(),
    );
  }

}

class OnMapScreen extends StatefulWidget {
  const OnMapScreen({super.key});

  @override
  OnMapScreenState createState() => OnMapScreenState();
}

class OnMapScreenState extends State<OnMapScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  late NMarker marker;

  DateTime selectedStartDate = DateTime(2012, 6, 12);
  DateTime selectedEndDate = DateTime(2025, 6, 12);
  DiaryInfo selectedDiary = DiaryInfo(lat: 1, lng: 1, title: "test", date: "test", content: "test");
  bool visible_status = false;
  late Set<NMarker> markers;


  final Completer<NaverMapController> mapControllerCompleter = Completer();

  NaverMapController? _controller;
  NCameraPosition? cameraPosition;

  void setMarkers(context) async {
    visible_status = false;
    _controller!.clearOverlays();
    List<DiaryInfo> infos = await _dbHelper.infos();
    // List<DiaryInfo> infos = [];
    // infos.add(DiaryInfo(id: 1, lat: 37.5126, lng: 126.9251, title: "안녕친구야", date: "2024년 12월 24일", content: "그만 하고 싶다."));
    // infos.add(DiaryInfo(id: 2, lat: 37.4126, lng: 126.8251, title: "안녕친구", date: "2024년 12월 26일", content: "그만 하고 싶다."));
    markers = Set();
    int index = 0;
    await Future.forEach(infos, (info) async {
      if(DateTime.parse(info.date.replaceAll("년 ", "-").replaceAll("월 ", "-").replaceAll("일", "")).isAfter(selectedStartDate) && DateTime.parse(info.date.replaceAll("년 ", "-").replaceAll("월 ", "-").replaceAll("일", "")).isBefore(selectedEndDate)) {
        print("forEach");
        markers.add(NMarker(
          id: info.id.toString(),
          position: NLatLng(info.lat, info.lng),
          icon: await NOverlayImage.fromWidget(
            widget: Icon(
              Icons.radio_button_checked_rounded,
              color: Colors.pink.shade200,
            ),
            size: Size(20, 20),
            context: context
          )
        ));
        markers.elementAt(index++).setOnTapListener((NMarker marker) {
          visible_status = true;
          selectedDiary = info;
          print("마커가 선택되었습니다.");
          print(selectedDiary.id);
          setState(() {
            setState(() { });
          });
        });
      }
    });
    _controller!.addOverlayAll(markers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              locale: Locale("ko"),
              initialCameraPosition: NCameraPosition(
                target: NLatLng(37.5126, 126.9263806),
                zoom: 15
              ),
              indoorEnable: true,
              locationButtonEnable: false,
              consumeSymbolTapEvents: false,
            ),
            onMapReady: (controller) async {
              mapControllerCompleter.complete(controller);
              _controller = controller;
              setMarkers(context);
            },
            onMapTapped: (point, latLng) {
              visible_status = false;
              setState(() {
                setState(() { });
              });
            },
            onCameraChange: (reason, animated) {
              visible_status = false;
              setState(() {
                setState(() { });
              });
            },
            
          ),
          Align(
            alignment: Alignment.center,
            child: Visibility(
              visible: !visible_status,
              child: Icon(Icons.location_pin, size: 40, color: Colors.pink[100]),
            )
          ),
          Align(
            alignment: Alignment(0, -0.85),
            child: Visibility(
              visible: true,
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30)
                ),
                width: 380,
                child: Row(
                  children: <Widget>[
                    InkWell(
                      onTap: () async {
                        final DateTime ?pickedStart = await showDatePicker(
                          context: context,
                          initialDate: selectedStartDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2025),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.pink.shade100,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: Colors.black,
                                ),
                                dialogBackgroundColor: Colors.white
                              ),
                              child: child!,
                            );
                          },
                        );
                        if(pickedStart != null && pickedStart != selectedStartDate) {
                          setState(() {
                            selectedStartDate = pickedStart;
                            setMarkers(context);
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30)
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.calendar_today, color: Colors.black),
                            SizedBox(width: 30),
                            Text(
                              "${selectedStartDate.toLocal()}".split(' ')[0],
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                                fontSize: 18
                              ),
                            ),
                            SizedBox(width: 30),
                            Text(
                              ":",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 18
                              ),
                            ),
                          ],
                        ),
                        height: 50,
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final DateTime ?pickedEnd = await showDatePicker(
                          context: context,
                          initialDate: selectedEndDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2025),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.pink.shade100,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: Colors.black,
                                ),
                                dialogBackgroundColor: Colors.white
                              ),
                              child: child!,
                            );
                          },
                        );
                        if(pickedEnd != null && pickedEnd != selectedEndDate) {
                          setState(() {
                            selectedEndDate = pickedEnd;
                            setMarkers(context);
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30)
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              "${selectedEndDate.toLocal()}".split(' ')[0],
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                                fontSize: 18
                              ),
                            ),
                            SizedBox(width: 10),
                          ],
                        ),
                        height: 50,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment(0, 0.85),
            child: Visibility(
              visible: visible_status,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15)
                ),
                padding: EdgeInsets.all(10),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              margin: EdgeInsets.only(left: 5),
                              child: Text(
                                selectedDiary.date, // selectedDiary.date
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.only(left: 5),
                              child: Text(
                                selectedDiary.title,     // selectedDiary.title
                                style: TextStyle(
                                  fontSize: 24
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          margin: EdgeInsets.only(right: 5),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => CreateNewDiaryScreen(info: selectedDiary))
                              ).then((result) => setMarkers(context));
                            },
                            child: Text(
                              "자세히 보기",
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink.shade200
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 10),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.grey,
                        ),
                        borderRadius: BorderRadius.circular(15)
                      ),
                      child: Text(
                        selectedDiary.content,             // selectedDiary.content
                      ),
                      width: 350,
                      height: 210,
                    ),
                  ],
                ),
                width: 380,
                height: 300,
              ),
            ),
          )
        ]
      ),
      floatingActionButton: Visibility(
        visible: !visible_status,
        child: FloatingActionButton(
          onPressed: () async {
            final cameraPosition = await _controller?.getCameraPosition();
            final lat = cameraPosition!.target.latitude;
            final lon = cameraPosition!.target.longitude;
            DiaryInfo info = DiaryInfo(lat: lat, lng: lon, title: "", date: DateFormat("yyyy년 MM월 dd일").format(DateTime.now()), content: "");
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CreateNewDiaryScreen(info: info))
            ).then((result) => setMarkers(context));
            // 이 버튼은 그냥 페이지 이동만 해야할 듯
            // 데이터베이스에 삽입 후 마커 생성
            // final marker = NMarker(id: "?", position: NLatLng(cameraPosition!.target.latitude, cameraPosition!.target.longitude));
            // print(cameraPosition!.target.latitude);
          },
          child: Icon(Icons.bookmark_add_outlined, size: 40, color: Colors.pink.shade200),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class CreateNewDiaryScreen extends StatefulWidget {
  final dynamic info;

  CreateNewDiaryScreen({Key? key, @required this.info}) : super(key: key);

  @override
  CreateNewDiaryScreenState createState() => CreateNewDiaryScreenState();
}

class CreateNewDiaryScreenState extends State<CreateNewDiaryScreen> {
  final TextEditingController _controllerForTitle = TextEditingController();
  final TextEditingController _controllerForContent = TextEditingController();
  late DiaryInfo info = widget.info;
  late DateTime selectedDate = DateTime.parse(info.date.replaceAll("년 ", "-").replaceAll("월 ", "-").replaceAll("일", ""));
  late double lat = info.lat;
  late double lon = info.lng;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  void _addDiaryInfo(context) async {
    if(_controllerForTitle.text.isNotEmpty && _controllerForContent.text.isNotEmpty) {
      await _dbHelper.insert(DiaryInfo(lat: lat, lng: lon, title: _controllerForTitle.text, date: DateFormat("yyyy년 MM월 dd일").format(selectedDate), content: _controllerForContent.text));
      _controllerForTitle.clear();
      _controllerForContent.clear();
      setState(() {
        setState(() { });
      });
      Navigator.pop(context);
    }
  }

  void _updateDiaryInfo(context) async {
    if(_controllerForTitle.text.isNotEmpty && _controllerForContent.text.isNotEmpty) {
      await _dbHelper.update(DiaryInfo(id: info.id, lat: lat, lng: lon, title: _controllerForTitle.text, date: DateFormat("yyyy년 MM월 dd일").format(selectedDate), content: _controllerForContent.text));
      _controllerForTitle.clear();
      _controllerForContent.clear();
      setState(() {
        setState(() { });
      });
      Navigator.pop(context);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        margin: EdgeInsets.only(top: 60, bottom: 10, left: 10, right: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey
          ),
          borderRadius: BorderRadius.circular(15)
        ),
        child: Column(
          children: <Widget>[
            Container(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          child: InkWell(
                            onTap: () async {
                              final DateTime ?picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2025),
                                builder: (context, child) {
                                  return Theme(
                                    data: ThemeData.light().copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: Colors.pink.shade100,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: Colors.black,
                                      ),
                                      dialogBackgroundColor: Colors.white
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if(picked != null && picked != selectedDate) {
                                setState(() {
                                  selectedDate = picked;
                                  // 날짜대로 일기를 불러오는 로직
                                });
                              }
                            },
                            child: Container(
                              margin: EdgeInsets.only(left: 10),
                              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                              ),
                              child: Text(
                                DateFormat("yyyy년 MM월 dd일").format(selectedDate),
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16
                                ),
                              ),
                              height: 50,
                            ),
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(left: 25, top: 5),
                          child: TextField(
                            controller: _controllerForTitle..text = info.title,
                            style: TextStyle(
                              fontSize: 24
                            ),
                            decoration: InputDecoration(
                              hintText: "제목을 입력하세요.",
                            ),
                          ),
                          width: 250,
                          height: 30,
                        )  // 제목 입력 부분
                      ],
                    ),
                    height: 100,
                  ),
                  Container(
                    margin: EdgeInsets.only(right: 25),
                    child: Column(
                      children: <Widget>[
                        Container(
                          child: ElevatedButton(
                            onPressed: () {
                              if(info.id != null) {
                                _updateDiaryInfo(context);
                              } else {
                                _addDiaryInfo(context);
                              }
                            },
                            child: Text(
                              "저장",
                              style: TextStyle(
                                color: Colors.white
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink.shade200
                            ),
                          ),
                        ),
                        Container(
                          child: TextButton(
                            onPressed: () {
                              if(info.id != null) {
                                _dbHelper.delete(info.id!);
                                setState(() {
                                  setState(() { });
                                });
                              }
                              Navigator.pop(context);
                            },
                            child: Icon(Icons.highlight_remove),
                          )
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey
                ),
                borderRadius: BorderRadius.circular(15)
              ),
              child: TextField(
                controller: _controllerForContent..text = info.content,   // _controllerForContent..text = selectedDiary.content
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: "내용을 입력하세요.",
                  border: InputBorder.none
                ),
              ),
              width: 350,
              height: 700,
            ),
          ],
        ),
        height: 820,
      ),
      resizeToAvoidBottomInset: false,
    );
  }
}