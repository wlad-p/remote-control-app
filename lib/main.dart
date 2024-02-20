import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main(){
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bohnzimmer',
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Bohnung'),
        backgroundColor: Colors.lightBlue,
      ),
      body: Center(
          child: LightsDisplay(),
      )
    );
  }
}

class LightsDisplay extends StatefulWidget {
  LightsDisplay({super.key});

  @override
  State<LightsDisplay> createState() => _LightsDisplayState();
}

class _LightsDisplayState extends State<LightsDisplay> {

  final client = MqttServerClient('', '');
  String username = "";
  String password = "";
  int pongCount = 0;
  String mqttMessage = "";

  Future<void> initMqttClient() async{
    client.logging(on: true);
    client.setProtocolV311();
    client.keepAlivePeriod = 20;
    client.connectTimeoutPeriod = 2000; // milliseconds
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onSubscribed = onSubscribed;
    client.pongCallback = pong;

    final connMess = MqttConnectMessage()
        .withClientIdentifier('client')
        .withWillTopic('main') // If you set this you must set a will message
        .withWillMessage('Flutter App connected')
        .startClean() // Non persistent session for testing
        .authenticateAs(username, password)
        .withWillQos(MqttQos.atLeastOnce);
    print('Mosquitto client connecting....');
    client.connectionMessage = connMess;


    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      // Raised by the client when connection fails.
      print('EXAMPLE::client exception - $e');
      client.disconnect();
    } on SocketException catch (e) {
      // Raised by the socket layer
      print('EXAMPLE::socket exception - $e');
      client.disconnect();
    }


    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('Mosquitto client connected');
    } else {
      print(
          'ERROR Mosquitto client connection failed - disconnecting, status is ${client.connectionStatus}');
      client.disconnect();
      exit(-1);
    }

    print('Subscribing to the test topic');
    const topic = 'test'; // Not a wildcard topic
    client.subscribe(topic, MqttQos.atMostOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt =
      MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      setState(() {
        mqttMessage = pt;
      });
    });

  }

  @override
  void initState() {
    super.initState();
    initMqttClient();
  }

  void publish(){
    const pubTopic = 'cmnd/ambient-light/Power';
    final builder = MqttClientPayloadBuilder();
    builder.addString('TOGGLE');
    client.publishMessage(pubTopic, MqttQos.exactlyOnce, builder.payload!);
  }

  void onDisconnected() {
    print('Client disconnection');
    if (client.connectionStatus!.disconnectionOrigin ==
        MqttDisconnectionOrigin.solicited) {
      print('EXAMPLE::OnDisconnected callback is solicited, this is correct');
    } else {
      print(
          'EXAMPLE::OnDisconnected callback is unsolicited or none, this is incorrect - exiting');
      exit(-1);
    }
    if (pongCount == 3) {
      print('EXAMPLE:: Pong count is correct');
    } else {
      print('EXAMPLE:: Pong count is incorrect, expected 3. actual $pongCount');
    }
  }

  void onSubscribed(String topic) {
    print('Subscription confirmed for topic $topic');
  }

  void onConnected() {
    print(
        'Client connection was successful');
  }

  void pong() {
    print('EXAMPLE::Ping response client callback invoked');
    pongCount++;
  }

  @override
  Widget build(BuildContext context){
    return Center(
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.all(50),
          backgroundColor: Colors.lightBlue
        ),
        child: Text("AmbientLight",
        style: TextStyle(
          color: Colors.white
        ),),
        onPressed: publish,
      ),
    );
  }
}

