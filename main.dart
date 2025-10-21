import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(FlappyCricketApp());
}

class FlappyCricketApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flappy Cricket',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Color(0xFFF6F8FA),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(),
    );
  }
}

class Player {
  final String id;
  String name;
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
  bool out = false;

  Player({required this.id, required this.name});
}

class Bowler {
  final String id;
  String name;
  int ballsBowled = 0;
  int runsConceded = 0;
  int wickets = 0;

  Bowler({required this.id, required this.name});
  String oversString() {
    final o = ballsBowled ~/ 6;
    final b = ballsBowled % 6;
    return "\$o.\$b";
  }
  double economy() {
    if (ballsBowled == 0) return 0.0;
    return runsConceded * 6.0 / ballsBowled;
  }
}

enum ExtraType { none, wide, noball, bye, legbye }

class BallEvent {
  final int over;
  final int ballInOver;
  final String batsmanId;
  final String bowlerId;
  final int runs;
  final bool isWicket;
  final ExtraType extra;
  final int extraRuns;
  BallEvent({
    required this.over,
    required this.ballInOver,
    required this.batsmanId,
    required this.bowlerId,
    required this.runs,
    this.isWicket = false,
    this.extra = ExtraType.none,
    this.extraRuns = 0,
  });
}

class Team {
  final String id;
  String name;
  List<Player> players = [];
  List<Bowler> bowlers = [];
  Team({required this.id, required this.name});
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final uuid = Uuid();
  Team teamA = Team(id: 'A', name: 'Team A');
  Team teamB = Team(id: 'B', name: 'Team B');

  // match state
  bool inningsStarted = false;
  Team? batting;
  Team? bowling;
  int totalOvers = 20;
  List<List<BallEvent>> overEvents = [];
  int totalRuns = 0;
  int totalWickets = 0;
  int ballsBowled = 0; // legal balls
  String? strikerId;
  String? nonStrikerId;
  String? currentBowlerId;

  // UI inputs
  final TextEditingController oversController = TextEditingController(text: '20');
  final TextEditingController playersControllerA = TextEditingController(text: 'Player 1,Player 2,Player 3,Player 4,Player 5');
  final TextEditingController playersControllerB = TextEditingController(text: 'Bowler 1,Bowler 2,Bowler 3');

  @override
  void initState() {
    super.initState();
    // default players
    _applyPlayersFromText(teamA, playersControllerA.text);
    _applyPlayersFromText(teamB, playersControllerB.text);
  }

  void _applyPlayersFromText(Team t, String raw) {
    t.players = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).map((n) => Player(id: uuid.v4(), name: n)).toList();
    // by default create bowlers same names
    t.bowlers = t.players.map((p) => Bowler(id: uuid.v4(), name: p.name)).toList();
  }

  void startInnings() {
    final overs = int.tryParse(oversController.text) ?? 20;
    if (teamA.players.length < 2 || teamB.bowlers.isEmpty) {
      _show('Please add at least 2 players & 1 bowler');
      return;
    }
    setState(() {
      totalOvers = overs;
      inningsStarted = true;
      batting = teamA;
      bowling = teamB;
      overEvents = [[]];
      totalRuns = 0;
      totalWickets = 0;
      ballsBowled = 0;
      strikerId = batting!.players[0].id;
      nonStrikerId = batting!.players.length > 1 ? batting!.players[1].id : batting!.players[0].id;
      currentBowlerId = bowling!.bowlers[0].id;
    });
  }

  void recordBall({required int runs, bool isWicket = false, ExtraType extra = ExtraType.none, int extraRuns = 0}) {
    if (!inningsStarted || batting == null || bowling == null) return;
    final bowler = bowling!.bowlers.firstWhere((b) => b.id == currentBowlerId);
    final striker = batting!.players.firstWhere((p) => p.id == strikerId);
    final effectiveRuns = runs + extraRuns;
    // update totals
    setState(() {
      totalRuns += effectiveRuns;
      bowler.runsConceded += effectiveRuns;
      // extras wide/noball do not count as legal ball
      final isLegal = !(extra == ExtraType.wide || extra == ExtraType.noball);
      if (isLegal) {
        ballsBowled += 1;
        bowler.ballsBowled += 1;
        striker.balls += 1;
      }
      if (extra != ExtraType.wide) {
        striker.runs += runs;
        if (runs == 4) striker.fours += 1;
        if (runs == 6) striker.sixes += 1;
      }
      if (isWicket) {
        totalWickets += 1;
        striker.out = true;
        bowler.wickets += 1;
      }
      // add event
      final overIndex = overEvents.isEmpty ? 0 : overEvents.length - 1;
      final ballInOver = ( (ballsBowled % 6) == 0 && isLegal ) ? 6 : (ballsBowled % 6);
      overEvents.last.add(BallEvent(
        over: overIndex + 1,
        ballInOver: ballInOver,
        batsmanId: striker.id,
        bowlerId: bowler.id,
        runs: runs,
        isWicket: isWicket,
        extra: extra,
        extraRuns: extraRuns,
      ));
      // rotate strike
      final runsForStrike = (extra == ExtraType.wide) ? 0 : runs + extraRuns;
      if (runsForStrike % 2 == 1 && !isWicket) {
        final tmp = strikerId; strikerId = nonStrikerId; nonStrikerId = tmp;
      }
      // over finished?
      if (isLegal && ballsBowled % 6 == 0) {
        // new over
        overEvents.add([]);
        // swap strike
        final tmp = strikerId; strikerId = nonStrikerId; nonStrikerId = tmp;
      }
    });
  }

  double runRate() {
    final overs = ballsBowled / 6.0;
    if (overs == 0) return 0.0;
    return totalRuns / overs;
  }

  double requiredRate(int target) {
    if (totalRuns >= target) return 0.0;
    final runsLeft = target - totalRuns;
    final ballsLeft = (totalOvers * 6) - ballsBowled;
    if (ballsLeft <= 0) return double.infinity;
    return runsLeft * 6.0 / ballsLeft;
  }

  void undoLast() {
    if (overEvents.isEmpty) return;
    final lastOver = overEvents.last;
    if (lastOver.isEmpty) {
      if (overEvents.length == 1) return;
      overEvents.removeLast();
      undoLast();
      return;
    }
    final ev = lastOver.removeLast();
    setState(() {
      final bowler = bowling!.bowlers.firstWhere((b) => b.id == ev.bowlerId);
      final batsman = batting!.players.firstWhere((p) => p.id == ev.batsmanId);
      final effective = ev.runs + ev.extraRuns;
      totalRuns = (totalRuns - effective).clamp(0, 9999);
      bowler.runsConceded = (bowler.runsConceded - effective).clamp(0, 9999);
      final isLegal = !(ev.extra == ExtraType.wide || ev.extra == ExtraType.noball);
      if (isLegal) {
        ballsBowled = (ballsBowled - 1).clamp(0, 9999);
        bowler.ballsBowled = (bowler.ballsBowled - 1).clamp(0, 9999);
        batsman.balls = (batsman.balls - 1).clamp(0, 9999);
      }
      if (ev.extra != ExtraType.wide) {
        batsman.runs = (batsman.runs - ev.runs).clamp(0, 9999);
        if (ev.runs == 4) batsman.fours = (batsman.fours - 1).clamp(0, 9999);
        if (ev.runs == 6) batsman.sixes = (batsman.sixes - 1).clamp(0, 9999);
      }
      if (ev.isWicket) {
        totalWickets = (totalWickets - 1).clamp(0, 9999);
        batsman.out = false;
        bowler.wickets = (bowler.wickets - 1).clamp(0, 9999);
      }
    });
  }

  Future<void> exportPdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Header(level: 0, child: pw.Text('Match Summary', style: pw.TextStyle(fontSize: 24))),
            pw.Text('Score: \$totalRuns/\$totalWickets'),
            pw.Text('Overs: \${ballsBowled ~/ 6}.\${ballsBowled % 6}'),
            pw.SizedBox(height: 8),
            pw.Text('Batsmen', style: pw.TextStyle(fontSize: 18)),
            pw.ListView.builder(
              itemCount: batting!.players.length,
              itemBuilder: (context, index) {
                final p = batting!.players[index];
                return pw.Text('${p.name} - \${p.runs} (\${p.balls}) 4s:\${p.fours} 6s:\${p.sixes} \${p.out ? "OUT" : "not out"}');
              },
            ),
            pw.SizedBox(height: 8),
            pw.Text('Bowlers', style: pw.TextStyle(fontSize: 18)),
            pw.ListView.builder(
              itemCount: bowling!.bowlers.length,
              itemBuilder: (context, index) {
                final b = bowling!.bowlers[index];
                return pw.Text('\${b.name} - \${b.ballsBowled ~/ 6}.\${b.ballsBowled % 6} overs  \${b.runsConceded}/\${b.wickets}  Econ:\${b.economy().toStringAsFixed(2)}');
              },
            ),
            pw.SizedBox(height: 8),
            pw.Text('Over-wise', style: pw.TextStyle(fontSize: 18)),
            ...overEvents.asMap().entries.map((entry) {
              final oi = entry.key;
              final over = entry.value;
              if (over.isEmpty) return pw.Text('Over \${oi+1}: -');
              final s = over.map((ev) {
                var t = '\${ev.ballInOver}:\${ev.runs}';
                if (ev.extra != ExtraType.none) t += ' (\${ev.extra.toString().split('.').last.substring(0,2)}\${ev.extraRuns>0?ev.extraRuns:""})';
                if (ev.isWicket) t += ' W';
                return t;
              }).join(' | ');
              return pw.Text('Over \${oi+1}: \$s');
            })
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  void _show(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flappy Cricket — Sports Theme'),
        actions: [
          IconButton(icon: Icon(Icons.picture_as_pdf), onPressed: inningsStarted ? exportPdf : null),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Flexible(
              flex: 2,
              child: Column(
                children: [
                  Card(
                    color: Colors.green[800],
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(teamA.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('Players: \${teamA.players.map((p) => p.name).join(", ")}', style: TextStyle(color: Colors.white70))
                          ])),
                          SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(teamB.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('Bowlers: \${teamB.bowlers.map((b) => b.name).join(", ")}', style: TextStyle(color: Colors.white70))
                          ])),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  if (!inningsStarted) ...[
                    _teamEditorCard('Team A players (comma separated)', playersControllerA, () {
                      _applyPlayersFromText(teamA, playersControllerA.text);
                      setState((){});
                    }),
                    SizedBox(height: 6),
                    _teamEditorCard('Team B bowlers (comma separated)', playersControllerB, () {
                      _applyPlayersFromText(teamB, playersControllerB.text);
                      setState((){});
                    }),
                    SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: TextField(controller: oversController, decoration: InputDecoration(labelText: 'Overs'))),
                      SizedBox(width: 8),
                      ElevatedButton(onPressed: startInnings, child: Text('Start Innings'))
                    ]),
                  ] else ...[
                    _scoreboardCard(),
                    SizedBox(height: 8),
                    _runControls()
                  ]
                ],
              ),
            ),
            SizedBox(width: 12),
            Container(
              width: 360,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('History & Stats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Expanded(child: ListView(
                    children: [
                      if (!inningsStarted) Text('No innings started') else Column(children: [
                        Text('Score: \$totalRuns/\$totalWickets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Overs: \${ballsBowled ~/ 6}.\${ballsBowled % 6}'),
                        Text('Run rate: \${runRate().toStringAsFixed(2)}'),
                        SizedBox(height: 8),
                        Text('Batsmen', style: TextStyle(fontWeight: FontWeight.bold)),
                        ...batting!.players.map((p) => ListTile(
                          title: Text(p.name),
                          trailing: Text('\${p.runs} (\${p.balls})'),
                          subtitle: Text('4s:\${p.fours} 6s:\${p.sixes} \${p.out? "OUT": "not out"}'),
                        )),
                        SizedBox(height: 6),
                        Text('Bowlers', style: TextStyle(fontWeight: FontWeight.bold)),
                        ...bowling!.bowlers.map((b) => ListTile(
                          title: Text(b.name),
                          trailing: Text('\${b.ballsBowled ~/ 6}.\${b.ballsBowled % 6}'),
                          subtitle: Text('\${b.runsConceded}/\${b.wickets} Econ:\${b.economy().toStringAsFixed(2)}'),
                        )),
                        SizedBox(height: 10),
                        Text('Over-wise', style: TextStyle(fontWeight: FontWeight.bold)),
                        ...overEvents.asMap().entries.map((e) {
                          final idx = e.key; final over = e.value;
                          return ListTile(title: Text('Over \${idx+1}'), subtitle: Text(over.isEmpty ? '-' : over.map((ev) => '\${ev.ballInOver}:\${ev.runs}\${ev.isWicket? ' W' : ''}').join(' | ')));
                        })
                      ])
                    ],
                  )),
                  Row(children: [
                    ElevatedButton(onPressed: inningsStarted ? undoLast : null, child: Text('Undo')),
                    SizedBox(width: 8),
                    ElevatedButton(onPressed: inningsStarted ? (){ setState(()=>inningsStarted=false); } : null, child: Text('End Innings')),
                    SizedBox(width: 8),
                    ElevatedButton(onPressed: inningsStarted ? exportPdf : null, child: Row(children: [Icon(Icons.picture_as_pdf), SizedBox(width:6), Text('Export PDF')]))
                  ])
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _teamEditorCard(String label, TextEditingController controller, VoidCallback onApply) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(controller: controller),
          SizedBox(height: 6),
          ElevatedButton(onPressed: onApply, child: Text('Apply'))
        ]),
      ),
    );
  }

  Widget _scoreboardCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Scoreboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('Score: \$totalRuns/\$totalWickets', style: TextStyle(fontSize: 16)),
          Text('Overs: \${ballsBowled ~/ 6}.\${ballsBowled % 6}'),
          Text('Run Rate: \${runRate().toStringAsFixed(2)}'),
        ]),
      ),
    );
  }

  Widget _runControls() {
    int runs = 0;
    bool wicket = false;
    ExtraType extra = ExtraType.none;
    int extraRuns = 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          Row(children: [
            DropdownButton<int>(
              value: runs,
              items: List.generate(7, (i) => i).map((v) => DropdownMenuItem(child: Text('\$v'), value: v)).toList(),
              onChanged: (v) => setState(()=> runs = v ?? 0),
            ),
            SizedBox(width: 8),
            Text('Extras:'),
            SizedBox(width: 8),
            DropdownButton<ExtraType>(
              value: extra,
              items: ExtraType.values.map((e) => DropdownMenuItem(child: Text(e.toString().split('.').last), value: e)).toList(),
              onChanged: (v) => setState(()=> extra = v ?? ExtraType.none),
            ),
            SizedBox(width: 8),
            ElevatedButton(onPressed: () {
              recordBall(runs: runs, isWicket: wicket, extra: extra, extraRuns: extraRuns);
            }, child: Text('Record Ball'))
          ]),
          SizedBox(height: 8),
          Row(children: [
            ElevatedButton(onPressed: () {
              // quick single runs presets
              recordBall(runs: 1);
            }, child: Text('+1')),
            SizedBox(width:6),
            ElevatedButton(onPressed: () {
              recordBall(runs: 4);
            }, child: Text('4')),
            SizedBox(width:6),
            ElevatedButton(onPressed: () {
              recordBall(runs: 6);
            }, child: Text('6')),
            SizedBox(width:6),
            ElevatedButton(onPressed: () {
              recordBall(runs: 0);
            }, child: Text('Dot'))
          ])
        ]),
      ),
    );
  }
}