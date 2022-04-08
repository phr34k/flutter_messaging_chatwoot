import 'dart:async';
import 'dart:convert';

import '../chatwoot_client_exception.dart';
import '../extensions.dart';
import '../requests/chatwoot_action.dart';
import '../requests/chatwoot_action_data.dart';
import '../requests/chatwoot_new_message_request.dart';

//import 'package:chatwoot_client_sdk/data/remote/service/chatwoot_client_api_interceptor.dart';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../entity/chatwoot_contact.dart';
import '../entity/chatwoot_conversation.dart';
import '../entity/chatwoot_message.dart';

/// Service for handling chatwoot api calls
/// See [ChatwootClientServiceImpl]
abstract class ChatwootClientService {
  final String _baseUrl;
  WebSocketChannel? connection;
  final Dio _dio;

  ChatwootClientService(this._baseUrl, this._dio);

  Future<ChatwootContact> updateContact(update,
      {required String inboxId, required String contactId});

  Future<ChatwootContact> getContact(
      {required String inboxId, required String contactId});

  Future<List<ChatwootConversation>> getConversations(
      {required String inboxId, required String contactId});

  Future<ChatwootMessage> createMessage(ChatwootNewMessageRequest request,
      {required String inboxId,
      required String contactId,
      required String conversationId});

  Future<ChatwootMessage> updateMessage(String messageIdentifier, update,
      {required String inboxId,
      required String contactId,
      required String conversationId});

  Future<List<ChatwootMessage>> getAllMessages(
      {required String inboxId,
      required String contactId,
      required String conversationId});

  void startWebSocketConnection(String contactPubsubToken,
      {WebSocketChannel Function(Uri)? onStartConnection});

  void sendAction(String contactPubsubToken, ChatwootActionType action);
}

class ChatwootClientServiceImpl extends ChatwootClientService {
  ChatwootClientServiceImpl(String baseUrl, {required Dio dio})
      : super(baseUrl, dio);

  ///Sends message to chatwoot inbox
  @override
  Future<ChatwootMessage> createMessage(ChatwootNewMessageRequest request,
      {required String inboxId,
      required String contactId,
      required String conversationId}) async {
    try {
      final createResponse = await _dio.post(
          "/public/api/v1/inboxes/$inboxId/contacts/$contactId/conversations/$conversationId/messages",
          data: request.toJson());
      if ((createResponse.statusCode ?? 0).isBetween(199, 300)) {
        return ChatwootMessage.fromJson(createResponse.data);
      } else {
        throw ChatwootClientException(
            createResponse.statusMessage ?? "unknown error",
            ChatwootClientExceptionType.SEND_MESSAGE_FAILED);
      }
    } on DioError catch (e) {
      throw ChatwootClientException(
          e.message, ChatwootClientExceptionType.SEND_MESSAGE_FAILED);
    }
  }

  ///Gets all messages of current chatwoot client instance's conversation
  @override
  Future<List<ChatwootMessage>> getAllMessages(
      {required String inboxId,
      required String contactId,
      required String conversationId}) async {
    try {
      final createResponse = await _dio.get(
          "/public/api/v1/inboxes/$inboxId/contacts/$contactId/conversations/$conversationId/messages");
      if ((createResponse.statusCode ?? 0).isBetween(199, 300)) {
        return (createResponse.data as List<dynamic>)
            .map(((json) => ChatwootMessage.fromJson(json)))
            .toList();
      } else {
        throw ChatwootClientException(
            createResponse.statusMessage ?? "unknown error",
            ChatwootClientExceptionType.GET_MESSAGES_FAILED);
      }
    } on DioError catch (e) {
      throw ChatwootClientException(
          e.message, ChatwootClientExceptionType.GET_MESSAGES_FAILED);
    }
  }

  ///Gets contact of current chatwoot client instance
  @override
  Future<ChatwootContact> getContact(
      {required String inboxId, required String contactId}) async {
    try {
      final createResponse =
          await _dio.get("/public/api/v1/inboxes/$inboxId/contacts/$contactId");
      if ((createResponse.statusCode ?? 0).isBetween(199, 300)) {
        return ChatwootContact.fromJson(createResponse.data);
      } else {
        throw ChatwootClientException(
            createResponse.statusMessage ?? "unknown error",
            ChatwootClientExceptionType.GET_CONTACT_FAILED);
      }
    } on DioError catch (e) {
      throw ChatwootClientException(
          e.message, ChatwootClientExceptionType.GET_CONTACT_FAILED);
    }
  }

  ///Gets all conversation of current chatwoot client instance
  @override
  Future<List<ChatwootConversation>> getConversations(
      {required String inboxId, required String contactId}) async {
    try {
      final createResponse = await _dio.get(
          "/public/api/v1/inboxes/$inboxId/contacts/$contactId/conversations");
      if ((createResponse.statusCode ?? 0).isBetween(199, 300)) {
        return (createResponse.data as List<dynamic>)
            .map(((json) => ChatwootConversation.fromJson(json)))
            .toList();
      } else {
        throw ChatwootClientException(
            createResponse.statusMessage ?? "unknown error",
            ChatwootClientExceptionType.GET_CONVERSATION_FAILED);
      }
    } on DioError catch (e) {
      throw ChatwootClientException(
          e.message, ChatwootClientExceptionType.GET_CONVERSATION_FAILED);
    }
  }

  ///Update current client instance's contact
  @override
  Future<ChatwootContact> updateContact(update,
      {required String inboxId, required String contactId}) async {
    try {
      final updateResponse = await _dio.patch(
          "/public/api/v1/inboxes/$inboxId/contacts/$contactId",
          data: update);
      if ((updateResponse.statusCode ?? 0).isBetween(199, 300)) {
        return ChatwootContact.fromJson(updateResponse.data);
      } else {
        throw ChatwootClientException(
            updateResponse.statusMessage ?? "unknown error",
            ChatwootClientExceptionType.UPDATE_CONTACT_FAILED);
      }
    } on DioError catch (e) {
      throw ChatwootClientException(
          e.message, ChatwootClientExceptionType.UPDATE_CONTACT_FAILED);
    }
  }

  ///Update message with id [messageIdentifier] with contents of [update]
  @override
  Future<ChatwootMessage> updateMessage(String messageIdentifier, update,
      {required String inboxId,
      required String contactId,
      required String conversationId}) async {
    try {
      final updateResponse = await _dio.patch(
          "/public/api/v1/inboxes/$inboxId/contacts/$contactId/conversations/${conversationId}/messages/$messageIdentifier",
          data: update);
      if ((updateResponse.statusCode ?? 0).isBetween(199, 300)) {
        return ChatwootMessage.fromJson(updateResponse.data);
      } else {
        throw ChatwootClientException(
            updateResponse.statusMessage ?? "unknown error",
            ChatwootClientExceptionType.UPDATE_MESSAGE_FAILED);
      }
    } on DioError catch (e) {
      throw ChatwootClientException(
          e.message, ChatwootClientExceptionType.UPDATE_MESSAGE_FAILED);
    }
  }

  @override
  void startWebSocketConnection(String contactPubsubToken,
      {WebSocketChannel Function(Uri)? onStartConnection}) {
    final socketUrl = Uri.parse(_baseUrl.replaceFirst("http", "ws") + "/cable");
    this.connection = onStartConnection == null
        ? WebSocketChannel.connect(socketUrl)
        : onStartConnection(socketUrl);
    connection!.sink.add(jsonEncode({
      "command": "subscribe",
      "identifier": jsonEncode(
          {"channel": "RoomChannel", "pubsub_token": contactPubsubToken})
    }));
  }

  @override
  void sendAction(String contactPubsubToken, ChatwootActionType actionType) {
    final ChatwootAction action;
    final identifier = jsonEncode(
        {"channel": "RoomChannel", "pubsub_token": contactPubsubToken});
    switch (actionType) {
      case ChatwootActionType.subscribe:
        action = ChatwootAction(identifier: identifier, command: "subscribe");
        break;
      default:
        action = ChatwootAction(
            identifier: identifier,
            data: ChatwootActionData(action: actionType),
            command: "message");
        break;
    }
    connection?.sink.add(jsonEncode(action.toJson()));
  }
}
