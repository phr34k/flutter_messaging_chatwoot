# flutter_messaging_chatwoot

This is an chatwoot backend implementation for the flutter_messaging_base library that aims to expose messaging backends in an unified approach. Making it easier for developers to integrate various backends in their app and provide rich customisations for it. This is an unofficial library, and is not supported by the origional authors.

## Main repository

https://github.com/phr34k/flutter_messaging_chatwoot

## Installing

To get started simply add `flutter_messaging_chatwoot:` and the latest version to your pubspec.yaml. Then run `flutter pub get`

## Using the widget

Integration with your app requires just a few lines of code. All that it requires is that you provide the `ChatwootSDK` provider, and the provider
will help you generate page routes to navigate to your inbox or specific chats.

```Dart
import 'package:flutter_chat_chatwoot_sdk/sdk.chatwoot.dart';
import 'package:flutter_chat_chatwoot_sdk/chatwoot/entity/chatwoot_user.dart';
import 'package:flutter_chat_chatwoot_sdk/chatwoot/callbacks.dart';

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
                  baseUrl: "https://app.chatwoot.com",
                  inboxIdentifier: "<<<your-inbox-identifier-here>>>",
                  user: ChatwootUser(
                    identifier: "test@test.com",
                    name: "Tester test",
                    email: "test@test.com",
                  ),
                  callbacks: ChatwootCallbacks(
                    
                  )))
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
    
```
That should get you up and running in just a few seconds ⚡️.


