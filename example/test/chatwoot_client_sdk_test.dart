import 'package:flutter_chat_chatwoot_sdk/chatwoot/callbacks.dart';
import 'package:flutter_chat_chatwoot_sdk/chatwoot/entity/chatwoot_contact.dart';
import 'package:flutter_chat_chatwoot_sdk/chatwoot/entity/chatwoot_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds one to input values', () {
    expect(1 + 1, 2);
  });

  test('adds one to input values', () {
    ChatwootHttpClient client = ChatwootHttpClient();
    expect(() => client.getConversations(), throwsA(isA<UnimplementedError>()));
  });

  test('create contact', () {
    ChatwootHttpClient client = ChatwootHttpClient();
    expect(client.createContact(), isInstanceOf<Future<ChatwootContact>>());
  });
}
