import 'package:flutter/material.dart';
import 'package:spacetraders/api.dart';
import 'package:spacetraders/data_structure.dart';
import 'package:spacetraders/galaxyview.dart';

void main() {
  runApp(MaterialApp(home: const App(), darkTheme: ThemeData.dark()));
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  DataStructure data = DataStructure();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: data,
      builder: (context, child) {
        return data.serverStatus == null
            ? Center(child: CircularProgressIndicator())
            : Scaffold(
                appBar: AppBar(
                  title: Text('Space Traders ${data.serverStatus!.version}'),
                  actions: [
                    OutlinedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Status',
                                    style: TextStyle(fontSize: 20),
                                  ),
                                  Text(data.serverStatus!.status),
                                  Text(
                                    'Last reset: ${data.serverStatus!.resetDate}',
                                  ),
                                  Text(
                                    'Resets ${data.serverStatus!.serverResetFrequency.name} (next reset ${data.serverStatus!.nextServerReset})',
                                  ),
                                  Text(
                                    'Last market update: ${data.serverStatus!.lastMarketUpdate}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: Text('Status'),
                    ),
                    SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Statistics',
                                    style: TextStyle(fontSize: 20),
                                  ),
                                  Text(
                                    'Accounts: ${data.serverStatus!.stats.accounts}',
                                  ),
                                  Text(
                                    'Agents: ${data.serverStatus!.stats.agents}',
                                  ),
                                  Text(
                                    'Ships: ${data.serverStatus!.stats.ships}',
                                  ),
                                  Text(
                                    'Systems: ${data.serverStatus!.stats.systems}',
                                  ),
                                  Text(
                                    'Waypoints: ${data.serverStatus!.stats.waypoints}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: Text('Statistics'),
                    ),
                    SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Most credits'),
                                      for (var (
                                            :AgentSymbol agentSymbol,
                                            :int credits,
                                          )
                                          in data
                                              .serverStatus!
                                              .leaderboards
                                              .mostCredits)
                                        Text('$agentSymbol: $credits'),
                                    ],
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Most submitted charts'),
                                      for (var (
                                            :AgentSymbol agentSymbol,
                                            :int chartCount,
                                          )
                                          in data
                                              .serverStatus!
                                              .leaderboards
                                              .mostSubmittedCharts)
                                        Text('$agentSymbol: $chartCount'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: Text('Leaderboards'),
                    ),
                    SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Announcements',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                      for (Announcement announcement
                                          in data
                                              .serverStatus!
                                              .announcements) ...[
                                        Text(
                                          announcement.title,
                                          style: TextStyle(fontSize: 20),
                                        ),
                                        SizedBox(
                                          width: 400,
                                          child: SelectableText(
                                            announcement.body,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: Text('Announcements'),
                    ),
                  ],
                ),
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
                  child: SizedBox.expand(
                    child: Column(
                      children: [
                        Text(data.serverStatus!.description),
                        Expanded(child: GalaxyView(data: data)),
                      ],
                    ),
                  ),
                ),
              );
      },
    );
  }
}
