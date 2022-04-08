import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_messaging_base/sdk.dart';

import 'package:flutter_messaging_chatwoot/sdk.chatwoot.dart';
import 'package:flutter_messaging_chatwoot/chatwoot/entity/chatwoot_user.dart';
import 'package:flutter_messaging_chatwoot/chatwoot/callbacks.dart';
import 'dart:io';
import 'package:hive/hive.dart';

void main() {
  var path = Directory.current.path;
  ChatwootSDK.register(Hive..init(path));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          Provider<SDK>(
              create: (_) => ChatwootSDK(
                  baseUrl: "<<<your-chatwoot-base-url-here>>>",
                  inboxIdentifier: "<<<your-inbox-identifier-here>>>",
                  user: ChatwootUser(
                    identifier: "test@test.com",
                    name: "Tester test",
                    email: "test@test.com",
                  ),
                  callbacks: ChatwootCallbacks(
                    onWelcome: () {
                      print("Welcome event received");
                    },
                    onPing: () {
                      print("Ping event received");
                    },
                    onConfirmedSubscription: () {
                      print("Confirmation event received");
                    },
                    onMessageDelivered: (_, __) {
                      print("Message delivered event received");
                    },
                    onMessageSent: (_, __) {
                      print("Message sent event received");
                    },
                    onConversationIsOffline: () {
                      print("Conversation is offline event received");
                    },
                    onConversationIsOnline: () {
                      print("Conversation is online event received");
                    },
                    onConversationStoppedTyping: (conversation) {
                      print("Conversation stopped typing event received");
                    },
                    onConversationStartedTyping: (conversation) {
                      print("Conversation started typing event received");
                    },
                  ))) /*,
          ProxyProvider<SDK, InboxProvider>(
            update: (_, sdk, __) => sdk.getInboxProvider(),
          ),
          */
        ],
        builder: (_, __) => MaterialApp(
              title: 'Flutter Demo',
              theme: ThemeData(
                primarySwatch: Colors.blue,
              ),

              initialRoute: '/',
              onGenerateRoute: (route) {
                if (route.name == '/') {
                  return Provider.of<SDK>(_, listen: false).getDefaultInboxUI();
                }

                return null;
              },

              //home: const InboxPage(title: 'Flutter Demo Home Page'),
            ));
  }
}
