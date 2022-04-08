import 'dart:async';

import '../chatwoot_client_exception.dart';
import '../extensions.dart';
//import 'package:chatwoot_client_sdk/data/remote/service/chatwoot_client_api_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../entity/chatwoot_contact.dart';
import '../entity/chatwoot_conversation.dart';
import '../entity/chatwoot_user.dart';

/// Service for handling chatwoot user authentication api calls
/// See [ChatwootClientAuthServiceImpl]
abstract class ChatwootClientAuthService {
  WebSocketChannel? connection;
  final Dio dio;

  ChatwootClientAuthService(this.dio);

  Future<ChatwootContact> createNewContact(ChatwootUser? user,
      {required String inboxIdentifier});

  Future<ChatwootConversation> createNewConversation(
      {required String inboxIdentifier, required String contactIdentifier});
}

/// Default Implementation for [ChatwootClientAuthService]
class ChatwootClientAuthServiceImpl extends ChatwootClientAuthService {
  ChatwootClientAuthServiceImpl({required Dio dio}) : super(dio);

  ///Creates new contact for inbox with [inboxIdentifier] and passes [user] body to be linked to created contact
  @override
  Future<ChatwootContact> createNewContact(ChatwootUser? user,
      {required String inboxIdentifier}) async {
    try {
      final createResponse = await dio.post(
          "/public/api/v1/inboxes/$inboxIdentifier/contacts",
          data: user?.toJson());
      if ((createResponse.statusCode ?? 0).isBetween(199, 300)) {
        //creating contact successful continue with request
        final contact = ChatwootContact.fromJson(createResponse.data);
        return contact;
      } else {
        throw ChatwootClientException(
            createResponse.statusMessage ?? "unknown error",
            ChatwootClientExceptionType.CREATE_CONTACT_FAILED);
      }
    } on DioError catch (e) {
      throw ChatwootClientException(
          e.message, ChatwootClientExceptionType.CREATE_CONTACT_FAILED);
    }
  }

  ///Creates a new conversation for inbox with [inboxIdentifier] and contact with source id [contactIdentifier]
  @override
  Future<ChatwootConversation> createNewConversation(
      {required String inboxIdentifier,
      required String contactIdentifier}) async {
    try {
      final createResponse = await dio.post(
          "/public/api/v1/inboxes/$inboxIdentifier/contacts/$contactIdentifier/conversations");
      if ((createResponse.statusCode ?? 0).isBetween(199, 300)) {
        //creating contact successful continue with request
        final newConversation =
            ChatwootConversation.fromJson(createResponse.data);
        return newConversation;
      } else {
        throw ChatwootClientException(
            createResponse.statusMessage ?? "unknown error",
            ChatwootClientExceptionType.CREATE_CONVERSATION_FAILED);
      }
    } on DioError catch (e) {
      throw ChatwootClientException(
          e.message, ChatwootClientExceptionType.CREATE_CONVERSATION_FAILED);
    }
  }
}
