import 'package:beeto_live/router/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Home"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(height: 64),
            TextButton(
              child: const Text("HOME"),
              onPressed: () {
                Navigator.pushNamed(context, RouterManager.CONNECT);
              },
            ),
            Container(height: 10),
            TextButton(
              child: const Text("CONNECT"),
              onPressed: () {
                Navigator.pushNamed(context, RouterManager.CONNECT);
              },
            ),
            Container(height: 10),
            TextButton(
              child: const Text("ROOM"),
              onPressed: () {
                Navigator.pushNamed(context, RouterManager.ROOM);
              },
            ),
            Spacer(),
          ],
        ),
      ),
      floatingActionButton: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: FloatingActionButton(
              child: const Text("Home"),
              heroTag: "Home",
              onPressed: () {
                Navigator.pushNamed(context, RouterManager.HOME);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: FloatingActionButton(
              child: const Text("DEMO"),
              heroTag: "DEMO",
              onPressed: () {
                Navigator.pushNamed(context, RouterManager.DEMO);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: FloatingActionButton(
              child: const Text("TEST"),
              heroTag: "TEST",
              onPressed: () {
                Navigator.pushNamed(context, RouterManager.TEST);
              },
            ),
          ),
        ],
      ),
    );
  }
}
