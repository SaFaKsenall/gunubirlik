
import 'package:flutter/material.dart';

class ConstructionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Yapım Aşamasında'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.build,
              size: 100.0,
              color: Colors.orange,
            ),
            SizedBox(height: 20),
            Text(
              'Bu özellik şu anda geliştirilme aşamasında.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              'Lütfen daha sonra tekrar deneyin.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}







/*import 'package:flutter/material.dart';

class cvpage extends StatefulWidget {
  cvpage({Key? key}) : super(key: key);

  @override
  _cvpageState createState() => _cvpageState();
}

class _cvpageState extends State<cvpage> {
  @override
  Widget build(BuildContext context) {
    return Container(
       child: ,
    );
  }
}*/