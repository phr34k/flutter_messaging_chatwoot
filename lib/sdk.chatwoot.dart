import 'dart:async';
import 'dart:convert';

//import 'package:chatwoot_client_sdk/chatwoot_client_sdk.dart';
//import 'package:chatwoot_client_sdk/data/local/dao/chatwoot_contact_dao.dart';
//import 'package:chatwoot_client_sdk/data/local/local_storage.dart';
//import 'package:chatwoot_client_sdk/data/remote/service/chatwoot_client_api_interceptor.dart';
//import 'package:chatwoot_client_sdk/di/modules.dart';
//import 'package:chatwoot_client_sdk/chatwoot_callbacks.dart';
//import 'package:chatwoot_client_sdk/chatwoot_client_sdk.dart';
//import 'package:chatwoot_client_sdk/data/chatwoot_repository.dart';
//import 'package:chatwoot_client_sdk/data/local/entity/chatwoot_contact.dart';
//import 'package:chatwoot_client_sdk/data/local/entity/chatwoot_conversation.dart';
//import 'package:chatwoot_client_sdk/data/local/entity/chatwoot_user.dart';
//import 'package:chatwoot_client_sdk/data/remote/requests/chatwoot_action_data.dart';
//import 'package:chatwoot_client_sdk/data/remote/requests/chatwoot_new_message_request.dart';
//import 'package:chatwoot_client_sdk/di/modules.dart';
//import 'package:chatwoot_client_sdk/chatwoot_parameters.dart';
//import 'package:chatwoot_client_sdk/repository_parameters.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod/riverpod.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import 'package:flutter_messaging_base/sdk.dart';
import 'package:flutter_messaging_base/ui.dart';
import 'package:flutter_messaging_base/model.dart' as types;

import 'chatwoot/params.dart';
import 'chatwoot/callbacks.dart';
import 'chatwoot/entity/chatwoot_contact.dart';
import 'chatwoot/entity/chatwoot_conversation.dart';
import 'chatwoot/entity/chatwoot_user.dart';
import 'chatwoot/entity/chatwoot_message.dart';
import 'chatwoot/entity/chatwoot_event.dart';
import 'chatwoot/http/chatwoot_client_auth_service.dart';
import 'chatwoot/http/chatwoot_client_service.dart';

import 'chatwoot/chatwoot_client_exception.dart';
import 'chatwoot/requests/chatwoot_action_data.dart';
import 'chatwoot/requests/chatwoot_new_message_request.dart';

import 'l10n.dart';
import 'theme.dart';

class ChatwootPersistance extends Persistance {
  final ChatwootSDK sdk;
  //final LocalStorage storage;
  //final Box<ChatwootMessage> _box;
  ChatwootPersistance(this.sdk /*, this.storage*/);

  /*
  List<ChatwootMessage> loadMessages(int conversationId) {
    var list = storage.messagesDao
        .getMessages()
        .where((element) => element.conversationId == conversationId);
  }
  */

  @override
  void clear() {
    //storage.clear(clearChatwootUserStorage: false);
  }
}

class ChatwootSDK extends SDK {
  final idGen = const Uuid();
  //final String baseUrl;
  //final String inboxIdentifier;
  //final bool _enablePersistence = false;
  late ChatwootParameters _parameters;
  late ChatwootUser _user;

  final StreamController _errors = StreamController.broadcast();
  List<ChatwootCallbacks> _wscallbacks = [];
  List<StreamSubscription> _subscriptions = [];
  bool _isListeningForEvents = false;
  Timer? _publishPresenceTimer;
  Timer? _presenceResetTimer;

  final ChatTheme? theme;
  final ChatL10n? l10n;
  final ChatwootCallbacks? callbacks;

  late Dio _dio;
  late ChatwootClientAuthService _authService;
  late ChatwootClientService _clientService;
  //late ChatwootClientApiInterceptor _interceptor;

  ChatwootContact? _contact;
  final List<ChatwootConversation> _conversations = [];

  late types.User _author;
  late types.User _bot;
  static Map<String, ProviderContainer> providerContainerMap = {};
  bool _isonline = false;

  static void register(HiveInterface hive) {
    hive.registerAdapter(ChatwootContactAdapter());
    hive.registerAdapter(ChatwootConversationAdapter());
    hive.registerAdapter(ChatwootMessageAdapter());
    hive.registerAdapter(ChatwootUserAdapter());
  }

  @override
  types.User get author => _author;

  bool get online => _isonline;

  Stream get errors => _errors.stream;

  ChatwootSDK(
      {bool showUserAvatars = true,
      bool showUserNames = true,
      DateFormat? timeFormat,
      DateFormat? dateFormat,
      bool enablePersistence = false,
      required String baseUrl,
      required String inboxIdentifier,
      required ChatwootUser user,
      WidgetBuilder? conversationBuilder,
      WidgetBuilder? inboxBuilder,
      this.theme,
      this.l10n,
      this.callbacks})
      : super(
            dateFormat: dateFormat,
            timeFormat: timeFormat,
            showUserNames: showUserNames,
            showUserAvatars: showUserAvatars,
            conversationBuilder: conversationBuilder,
            inboxBuilder: inboxBuilder) {
    _parameters = ChatwootParameters(
        /*
        clientInstanceKey: ChatwootClient.getClientInstanceKey(
            baseUrl: baseUrl,
            inboxIdentifier: inboxIdentifier,
            userIdentifier: user.identifier),
            */

        clientInstanceKey: "",
        isPersistenceEnabled: enablePersistence,
        baseUrl: baseUrl,
        inboxIdentifier: inboxIdentifier,
        userIdentifier: user.identifier);

    /*
    FakeData data = FakeData();
    data.generate(4);
    _author = data.author;
    messages.addAll(data.messages);
    conversations.addAll(data.conversations);    
    */

    _user = user;
    _bot = const types.User(id: "bot", firstName: "bot", lastName: "");

    _author =
        types.User(id: user.identifier!, firstName: user.name, lastName: "");

    providerContainerMap.putIfAbsent(
        _parameters.clientInstanceKey, () => ProviderContainer());

    //storage = localStorageProvider.builder;

    //initialize dio
    _dio = Dio(BaseOptions(baseUrl: _parameters.baseUrl));
    //_interceptor = ChatwootClientApiInterceptor(_parameters.inboxIdentifier, _localStorage, _authService)
    //_dio.interceptors.add(_interceptor);
    _authService = ChatwootClientAuthServiceImpl(dio: _dio);
    _clientService = ChatwootClientServiceImpl(baseUrl, dio: _dio);

    var selfCallbacks = ChatwootCallbacks(
        onMessageUpdated: (value) {
          int convIdx = _conversations
              .indexWhere((element) => element.id == value.conversationId);
          int msgIndx = _conversations[convIdx]
              .messages
              .indexWhere((element) => element.id == value.id);
          _conversations[convIdx].messages[msgIndx] = value;
          notifyInboxChanged();
        },
        onConversationOpened: (value) =>
            setConversationOpened(value.toString()),
        onConversationResolved: (value) =>
            setConversationResolved(value.toString()),
        onMessageReceived: (value) {
          int convIdx = _conversations
              .indexWhere((element) => element.id == value.conversationId);
          _conversations[convIdx].messages.add(value);
          notifyInboxChanged();
        });

    listen(selfCallbacks);

    //create a new contact or reuse the contact persisted on disk
    getOrCreate().then((value) async {
      _contact = value;

      //refresh the inbox
      var convs = await _clientService.getConversations(
          inboxId: inboxIdentifier, contactId: _contact!.contactIdentifier!);
      _conversations.addAll(convs);
      notifyInboxChanged();

      //start a websocket event
      listenForEvents();
    });
  }

  types.Message? _chatwootMessageToTextMessage(ChatwootMessage message,
      {String? echoId}) {
    //Sets avatar url to null if its a gravatar not found url
    //This enables placeholder for avatar to show
    String? avatarUrl = message.sender?.avatarUrl ?? message.sender?.thumbnail;
    if (avatarUrl?.contains("?d=404") ?? false) {
      avatarUrl = null;
    }

    if (message.attachments?.isNotEmpty ?? false) {
      return null;
    } else {
      if (message.messageType == 2) {
        return types.TextMessage(
            id: echoId ?? message.id.toString(),
            author: _bot,
            text: message.content ?? "",
            status: types.Status.seen,
            createdAt:
                DateTime.parse(message.createdAt).millisecondsSinceEpoch);
      } else {
        return types.TextMessage(
            id: echoId ?? message.id.toString(),
            author: message.isMine
                ? author
                : types.User(
                    id: message.sender!.id.toString() /*?? sdk.newMessageId()*/,
                    firstName: message.sender?.name,
                    lastName: "",
                    imageUrl: avatarUrl,
                  ),
            text: message.content ?? "",
            status: message.isMine ? types.Status.seen : types.Status.seen,
            createdAt:
                DateTime.parse(message.createdAt).millisecondsSinceEpoch);
      }
    }
  }

  @override
  Future<List<Conversation>> conversation() {
    var list = _conversations
        .map((e) => Conversation(e.id.toString(),
            unread: 0,
            status: e.status == "open" ? 0 : 1,
            messsages: e.messages
                .map((e) => _chatwootMessageToTextMessage(e)!)
                .toList()))
        .toList();

    /*
    for (var element in list) {
      element.messsages?.add(messages.first);
      element.messsages?.add(messages.last);
    }
    */

    return Future.value(list);
  }

  @override
  Future<List<types.Message>> getMessages({required String? conversationId}) {
    /*
    return Future.value(
        messages.where((element) => element.roomId == conversationId).toList());
*/

    var list = _conversations
        .where((element) => element.id!.toString() == conversationId)
        .map((e) => Conversation(e.id.toString(),
            unread: 0,
            messsages: e.messages
                .map((e) => _chatwootMessageToTextMessage(e)!)
                .toList()))
        .toList();
    return Future.value(list.isNotEmpty ? list.first.messsages : []);
  }

  @override
  Future<bool> getStatus({required String? conversationId}) {
    int convIdx = _conversations
        .indexWhere((element) => element.id.toString() == conversationId);
    return Future.value(_conversations[convIdx].status == "open");
  }

  Future<ChatwootContact> getOrCreate() async {
    var box = await Hive.openBox<ChatwootContact>('contact');
    ChatwootContact? _contact = box.get("contactid");
    if (_contact == null) {
      _contact = await _authService.createNewContact(_user,
          inboxIdentifier: _parameters.inboxIdentifier);
      await box.put("contactid", _contact!);
    } else {
      await _clientService.updateContact(
          {"email": _user.email, "name": _user.name},
          inboxId: _parameters.inboxIdentifier,
          contactId: _contact.contactIdentifier!);
      var s = await _clientService.getContact(
          inboxId: _parameters.inboxIdentifier,
          contactId: _contact.contactIdentifier!);
      _contact = ChatwootContact(
          id: _contact.id,
          contactIdentifier: _contact.contactIdentifier,
          pubsubToken: _contact.pubsubToken,
          name: _user.name!,
          email: _user.email!);
    }

    await box.close();
    return _contact!;
  }

  @override
  void addMessage(types.Message message) {
    /*
    var matchingConversations =
        conversations.where((element) => element.uuid == message.roomId);
    if (matchingConversations.isEmpty) {
      var conv = Conversation(message.roomId!, unread: 0);
      messages.add(message);
      conversations.add(conv);
      _conversationController.add(conv);
    } else {
      messages.add(message);
      _conversationController.add(matchingConversations.first);
    }
    */
  }

  @override
  Future<Conversation> create() async =>
      Future.value(Conversation(await newConversationId()));

  @override
  ChatTheme getTheme() => theme ?? const ChatwootDefaultChatTheme();
  @override
  ChatL10n getl10n() => l10n ?? const ChatwootDefaultL10n();
  @override
  Persistance getPersistances() {
    //final container = providerContainerMap[_parameters.clientInstanceKey]!;
    //final localStorage = container.read(localStorageProvider(_parameters));
    //return ChatwootPersistance(this, localStorage);
    throw UnimplementedError();
  }

  @override
  Future<String> newConversationId() async {
    var res = await _authService.createNewConversation(
        inboxIdentifier: _parameters.inboxIdentifier,
        contactIdentifier: _contact!.contactIdentifier!);
    _conversations.add(res);
    notifyInboxChanged();
    return res.id.toString();
  }

  Future<ChatwootMessage> send(types.TextMessage message) async {
    var res = await _clientService.createMessage(
        ChatwootNewMessageRequest(content: message.text, echoId: message.id),
        inboxId: _parameters.inboxIdentifier,
        contactId: _contact!.contactIdentifier!,
        conversationId: message.roomId!);
    _conversations
        .where((element) => element.id == res.conversationId)
        .first
        .messages
        .add(res);
    notifyInboxChanged();
    return res;
  }

  @override
  Future<String> newMessageId() => Future.value(idGen.v4());

  void listen(ChatwootCallbacks chatwootCallbacks) {
    _wscallbacks.add(chatwootCallbacks);
  }

  void unlisten(ChatwootCallbacks chatwootCallbacks) {
    _wscallbacks.remove(chatwootCallbacks);
  }

/*
  Future<ChatwootClient> createWeb(ChatwootCallbacks chatwootCallbacks) {
    return ChatwootClient.create(
        baseUrl: _parameters.baseUrl,
        inboxIdentifier: _parameters.inboxIdentifier,
        user: _user,
        enablePersistence: _parameters.isPersistenceEnabled,
        callbacks: chatwootCallbacks);
  }
  */

  @override
  bool get enablePersistence => _parameters.isPersistenceEnabled;

  @override
  InboxProvider getInboxProvider() => InboxProvider(this);

  @override
  ConversationProvider getConversationProvider({String? conversationId}) =>
      ChatwootConversationProvider(this, conversationId: conversationId);

  ///Send actions like user started typing
  void sendAction(ChatwootActionType action) {
    _clientService.sendAction(_contact!.pubsubToken!, action);
  }

  ///Publishes presence update to websocket channel at a 30 second interval
  void _publishPresenceUpdates() {
    _publishPresenceTimer?.cancel();
    _clientService.sendAction(
        _contact!.pubsubToken!, ChatwootActionType.update_presence);
    _publishPresenceTimer =
        Timer.periodic(const Duration(seconds: 25), (timer) {
      _clientService.sendAction(
          _contact!.pubsubToken!, ChatwootActionType.update_presence);
    });
  }

  /// Connects to chatwoot websocket and starts listening for updates
  ///
  /// Received events/messages are pushed through [ChatwootClient.callbacks]
  @override
  void listenForEvents() {
    _clientService.startWebSocketConnection(_contact!.pubsubToken!);

    final newSubscription = _clientService.connection!.stream.listen((event) {
      ChatwootEvent chatwootEvent = ChatwootEvent.fromJson(jsonDecode(event));

      if (chatwootEvent.type == ChatwootEventType.ping) {
        //callbacks?.onPing?.call();
        _wscallbacks.forEach(((element) => element.onPing?.call()));
      } else if (chatwootEvent.type == ChatwootEventType.welcome) {
        //callbacks?.onWelcome?.call();
        _wscallbacks.forEach(((element) => element.onWelcome?.call()));
      } else if (chatwootEvent.type == ChatwootEventType.confirm_subscription) {
        /*
        if (!_isListeningForEvents) {
          _isListeningForEvents = true;
        }        
        callbacks?.onConfirmedSubscription?.call();
        */

        _publishPresenceUpdates();
        _wscallbacks
            .forEach(((element) => element.onConfirmedSubscription?.call()));
      } else if (chatwootEvent.message?.event ==
          ChatwootEventMessageType.message_created) {
        print("here comes message: $event");
        final message = chatwootEvent.message!.data!.getMessage();
        //localStorage.messagesDao.saveMessage(message);
        if (message.isMine) {
          /*
          callbacks?.onMessageDelivered
              ?.call(message, chatwootEvent.message!.data!.echoId!);
          */
          _wscallbacks.forEach(((element) => element.onMessageDelivered
              ?.call(message, chatwootEvent.message!.data!.echoId!)));
        } else {
          /*
          callbacks?.onMessageReceived?.call(message);
          */
          _wscallbacks
              .forEach(((element) => element.onMessageReceived?.call(message)));
        }
      } else if (chatwootEvent.message?.event ==
          ChatwootEventMessageType.message_updated) {
        print("here comes the updated message: $event");

        final message = chatwootEvent.message!.data!.getMessage();
        //localStorage.messagesDao.saveMessage(message);

        //callbacks?.onMessageUpdated?.call(message);
        _wscallbacks
            .forEach(((element) => element.onMessageUpdated?.call(message)));
      } else if (chatwootEvent.message?.event ==
          ChatwootEventMessageType.conversation_typing_off) {
        //callbacks?.onConversationStoppedTyping?.call();
        _wscallbacks.forEach(((element) => element.onConversationStoppedTyping
            ?.call(chatwootEvent.message!.data!.conversation!.id!)));
      } else if (chatwootEvent.message?.event ==
          ChatwootEventMessageType.conversation_typing_on) {
        //callbacks?.onConversationStartedTyping?.call();
        _wscallbacks.forEach(((element) => element.onConversationStartedTyping
            ?.call(chatwootEvent.message!.data!.conversation!.id!)));
      } else if (chatwootEvent.message?.event ==
              ChatwootEventMessageType
                  .conversation_status_changed /*&&
          chatwootEvent.message?.data?.id ==
              (localStorage.conversationDao.getConversation()?.id ?? 0*/
          ) {
        //delete conversation result
        //localStorage.conversationDao.deleteConversation();
        //localStorage.messagesDao.clear();
        //callbacks?.onConversationResolved?.call();

        if (chatwootEvent.message?.data?.status == "resolved") {
          _wscallbacks.forEach(((element) => element.onConversationResolved
              ?.call(chatwootEvent.message!.data!.id!)));
        } else if (chatwootEvent.message?.data?.status == "open") {
          _wscallbacks.forEach(((element) => element.onConversationOpened
              ?.call(chatwootEvent.message!.data!.id!)));
        }
      } else if (chatwootEvent.message?.event ==
          ChatwootEventMessageType.presence_update) {
        final presenceStatuses =
            (chatwootEvent.message!.data!.users as Map<dynamic, dynamic>)
                .values;

        final isOnline = presenceStatuses
            .every((element) => element == "online" || element == "busy");
        _isonline = isOnline;

        if (isOnline) {
          _wscallbacks
              .forEach(((element) => element.onConversationIsOnline?.call()));
          //callbacks?.onConversationIsOnline?.call();
          //_presenceResetTimer?.cancel();
          //_startPresenceResetTimer();
        } else {
          //callbacks?.onConversationIsOffline?.call();
          _wscallbacks
              .forEach(((element) => element.onConversationIsOffline?.call()));
        }
      } else {
        print("chatwoot unknown event: $event");
      }
    }, onError: (_, __) {
      FlutterError.reportError(FlutterErrorDetails(exception: _, stack: __));
    });
    _subscriptions.add(newSubscription);
  }

  @override
  void setConversationResolved(String conversationId) {
    /*
    var matchingConversations =
        conversations.where((element) => element.uuid == conversationId);
    if (matchingConversations.isEmpty) {
      var conv = matchingConversations.first;
      conversations.remove(conv);
      conversations.add(Conversation(conv.uuid,
          unread: conv.unread, messsages: conv.messsages));
      _conversationController.add(matchingConversations.first);
    }
    */

    int convIdx = _conversations
        .indexWhere((element) => element.id.toString() == conversationId);
    _conversations[convIdx] = ChatwootConversation(
        id: _conversations[convIdx].id,
        inboxId: _conversations[convIdx].inboxId,
        status: "resolved",
        messages: _conversations[convIdx].messages,
        contact: _conversations[convIdx].contact);
    notifyInboxChanged();
  }

  @override
  void setConversationOpened(String conversationId) {
    /*
    var matchingConversations =
        conversations.where((element) => element.uuid == conversationId);
    if (matchingConversations.isEmpty) {
      var conv = matchingConversations.first;
      conversations.remove(conv);
      conversations.add(Conversation(conv.uuid,
          unread: conv.unread, messsages: conv.messsages));
      _conversationController.add(matchingConversations.first);
    }
    */

    int convIdx = _conversations
        .indexWhere((element) => element.id.toString() == conversationId);
    _conversations[convIdx] = ChatwootConversation(
        id: _conversations[convIdx].id,
        inboxId: _conversations[convIdx].inboxId,
        status: "open",
        messages: _conversations[convIdx].messages,
        contact: _conversations[convIdx].contact);
    notifyInboxChanged();
  }

  Future<bool> canReply(String conversationId) {
    int convIdx = _conversations
        .indexWhere((element) => element.id.toString() == conversationId);
    return Future.value(_conversations[convIdx].status == "open" ||
        (DateTime.parse(_conversations[convIdx].messages.last.createdAt)
                    .difference(DateTime.now()))
                .inHours >
            36);
  }
}

class ChatwootConversationProvider extends ConversationProvider {
  final ChatwootSDK _sdk;
  late ChatwootCallbacks? chatwootCallbacks;
  //ChatwootClient? chatwootClient;
  String? _conversationId;
  final MessageCollection<types.Message> _messages =
      MessageCollection<types.Message>();
  final StreamController _errors = StreamController.broadcast();
  final ValueNotifier<bool> _typing = ValueNotifier(false);
  final ValueNotifier<bool> _status = ValueNotifier(true);
  final ValueNotifier<bool> _canReply = ValueNotifier(true);
  final Completer<bool> _events = Completer<bool>();
  late ValueNotifier<bool> _isonline;

  @override
  Future<bool> get loaded => _events.future;

  @override
  Stream get errors => _errors.stream;

  @override
  SDK get sdk => _sdk;

  @override
  types.User get author => sdk.author;

  @override
  List<types.Message> get messages => _messages.collection;

  @override
  Listenable get changes => _messages;

  @override
  ValueListenable<bool> get online => _isonline;

  @override
  ValueListenable<bool> get typing => _typing;

  @override
  ValueListenable<bool> get status => _status;

  @override
  ValueListenable<bool> get canReply => _canReply;

  @override
  Future<String> getConversationId() async {
    if (_conversationId == null) {
      _conversationId = await _sdk.newConversationId();
      _canReply.value = await _sdk.canReply(_conversationId!);
      return Future.value(_conversationId!);
    } else {
      return Future.value(_conversationId!);
    }
  }

  @override
  Future<String> newMessageId() async {
    return sdk.newMessageId();
  }

  ChatwootConversationProvider(this._sdk, {String? conversationId}) {
    _isonline = ValueNotifier(_sdk.online);
    _conversationId = conversationId;

    ChatwootCallbacks? origional = _sdk.callbacks;
    chatwootCallbacks = ChatwootCallbacks(
      onWelcome: () {
        origional?.onWelcome?.call();
      },
      onPing: () {
        origional?.onPing?.call();
      },
      onConfirmedSubscription: () {
        origional?.onConfirmedSubscription?.call();
      },
      onConversationIsOnline: () {
        _isonline.value = true;
      },
      onConversationIsOffline: () {
        _isonline.value = false;
      },
      onConversationStartedTyping: (convId) {
        if (convId.toString() == conversationId) {
          beginTyping();
        }
      },
      onConversationStoppedTyping: (convId) {
        if (convId.toString() == conversationId) {
          endTyping();
        }
      },
      onPersistedMessagesRetrieved: (persistedMessages) {
        if (sdk.enablePersistence) {
          _messages.addAll(persistedMessages
              .map((message) => _chatwootMessageToTextMessage(message))
              .where((e) => e != null)
              .map((e) => e!));
        }
        origional?.onPersistedMessagesRetrieved?.call(persistedMessages);
      },
      onMessagesRetrieved: (messages) {
        if (messages.isEmpty) {
          return;
        }

        final chatMessages = messages
            .map((message) => _chatwootMessageToTextMessage(message))
            .where((e) => e != null)
            .map((e) => e!)
            .toList();
        final mergedMessages =
            <types.Message>{..._messages.collection, ...chatMessages}.toList();
        final now = DateTime.now().millisecondsSinceEpoch;
        mergedMessages.sort((a, b) {
          return (b.createdAt ?? now).compareTo(a.createdAt ?? now);
        });
        _messages.replaceAll(mergedMessages);
        origional?.onMessagesRetrieved?.call(messages);
      },
      onMessageReceived: (chatwootMessage) {
        if (chatwootMessage.conversationId?.toString() == conversationId) {
          var msg = _chatwootMessageToTextMessage(chatwootMessage);
          if (msg != null) _handleMessageReceived(msg);
        }

        origional?.onMessageReceived?.call(chatwootMessage);
      },
      onMessageDelivered: (chatwootMessage, echoId) {
        if (chatwootMessage.conversationId?.toString() == conversationId) {
          var msg =
              _chatwootMessageToTextMessage(chatwootMessage, echoId: echoId);
          if (msg != null) _handleMessageSent(msg);
        }
        origional?.onMessageDelivered?.call(chatwootMessage, echoId);
      },
      onMessageUpdated: (chatwootMessage) {
        if (chatwootMessage.conversationId?.toString() == conversationId) {
          var msg = _chatwootMessageToTextMessage(chatwootMessage,
              echoId: chatwootMessage.id.toString());
          if (msg != null) _handleMessageUpdated(msg);
        }
        origional?.onMessageUpdated?.call(chatwootMessage);
      },
      onMessageSent: (chatwootMessage, echoId) {
        if (chatwootMessage.conversationId?.toString() == conversationId) {
          if (chatwootMessage.attachments != null &&
              chatwootMessage.attachments!.isNotEmpty) {
            final textMessage = types.TextMessage(
                id: echoId,
                author: author,
                text: chatwootMessage.content ?? "",
                status: types.Status.delivered);
            _handleMessageSent(textMessage);
            origional?.onMessageSent?.call(chatwootMessage, echoId);
          } else {
            final textMessage = types.TextMessage(
                id: echoId,
                author: author,
                text: chatwootMessage.content ?? "",
                status: types.Status.delivered);
            _handleMessageSent(textMessage);
            origional?.onMessageSent?.call(chatwootMessage, echoId);
          }
        }
      },
      onConversationOpened: (int convId) async {
        /*
        final resolvedMessage = types.TextMessage(
            id: idGen.v4(),
            text: widget.l10n.conversationResolvedMessage,
            author: types.User( 
                id: idGen.v4(),
                firstName: "Bot",
                imageUrl:
                    "https://d2cbg94ubxgsnp.cloudfront.net/Pictures/480x270//9/9/3/512993_shutterstock_715962319converted_920340.png"),
            status: types.Status.delivered);
        addMessage(resolvedMessage);
        */
        if (convId.toString() == conversationId) {
          //sdk.setConversationOpened(conversationId!);
          _status.value = false;
        }
      },
      onConversationResolved: (int convId) async {
        /*
        final resolvedMessage = types.TextMessage(
            id: idGen.v4(),
            text: widget.l10n.conversationResolvedMessage,
            author: types.User( 
                id: idGen.v4(),
                firstName: "Bot",
                imageUrl:
                    "https://d2cbg94ubxgsnp.cloudfront.net/Pictures/480x270//9/9/3/512993_shutterstock_715962319converted_920340.png"),
            status: types.Status.delivered);
        addMessage(resolvedMessage);
        */
        if (convId.toString() == conversationId) {
          //sdk.setConversationResolved(conversationId!);
          _status.value = true;
        }
      },
      onError: (error) {
        if (error.type == ChatwootClientExceptionType.SEND_MESSAGE_FAILED) {
          _handleSendMessageFailed(error.data);
        }
        //print("Ooops! Something went wrong. Error Cause: ${error.cause}");
        origional?.onError?.call(error);
      },
    );

    _sdk.listen(chatwootCallbacks!);

/*
    (sdk as ChatwootSDK).createWeb(chatwootCallbacks!).then((client) {
      chatwootClient = client;
      //chatwootClient!.loadMessages();
    }).onError((error, stackTrace) {
      origional?.onError?.call(ChatwootClientException(
          error.toString(), ChatwootClientExceptionType.CREATE_CLIENT_FAILED));
    });
    */

    if (conversationId != null) {
      sdk.getStatus(conversationId: conversationId).then((value) {
        _status.value = value;
      });

      sdk.getMessages(conversationId: conversationId).then((value) {
        _messages.addAll(value);
        _events.complete(true);
      });
    } else {
      _events.complete(true);
    }
  }

  types.Message? _chatwootMessageToTextMessage(ChatwootMessage message,
      {String? echoId}) {
    //Sets avatar url to null if its a gravatar not found url
    //This enables placeholder for avatar to show
    String? avatarUrl = message.sender?.avatarUrl ?? message.sender?.thumbnail;
    if (avatarUrl?.contains("?d=404") ?? false) {
      avatarUrl = null;
    }

    if (message.attachments?.isNotEmpty ?? false) {
      return null;
    } else {
      if (message.messageType == 2) {
        return types.TextMessage(
            id: echoId ?? message.id.toString(),
            author: types.User(
              id: message.sender!.id.toString() /*?? sdk.newMessageId()*/,
              firstName: message.sender?.name,
              imageUrl: avatarUrl,
            ),
            text: message.content ?? "",
            status: types.Status.seen,
            createdAt:
                DateTime.parse(message.createdAt).millisecondsSinceEpoch);
      } else {
        return types.TextMessage(
            id: echoId ?? message.id.toString(),
            author: message.isMine
                ? author
                : types.User(
                    id: message.sender!.id.toString() /*?? sdk.newMessageId()*/,
                    firstName: message.sender?.name,
                    imageUrl: avatarUrl,
                  ),
            text: message.content ?? "",
            status: types.Status.seen,
            createdAt:
                DateTime.parse(message.createdAt).millisecondsSinceEpoch);
      }
    }
  }

  void _handleMessageReceived(types.Message message) {
    _messages.add(message);
    sdk.addMessage(message);
  }

  void _handleMessageUpdated(types.Message message) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    _messages.replace(index, message);
    sdk.updateMessage(message);
  }

  void _handleSendMessageFailed(String echoId) async {
    final index = _messages.indexWhere((element) => element.id == echoId);
    final msg = _messages.collection[index];
    var updatedMessage = msg.copyWith(status: types.Status.error);
    _messages.replace(index, updatedMessage);
    sdk.updateMessage(updatedMessage);
  }

  void _handleMessageSent(
    types.Message message,
  ) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    final msg = _messages.collection[index];
    if (msg.status == types.Status.seen) {
      return;
    }

    final updatedMessage = msg.copyWith(status: types.Status.sent);
    _messages.replace(index, updatedMessage);
    sdk.updateMessage(updatedMessage);
  }

  @override
  void updateMessage(types.Message message, types.PreviewData previewData) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    final msg = _messages.collection[index];
    final updatedMessage = msg.copyWith(previewData: previewData);
    _messages.replace(index, updatedMessage);
    sdk.updateMessage(updatedMessage);
  }

  @override
  void resendMessage(types.Message message) async {
    if (message is types.TextMessage) {
      //chatwootClient!.sendMessage(content: message.text, echoId: message.id);
    }

    final index = _messages.indexWhere((element) => element.id == message.id);
    final msg = _messages.collection[index];
    var updateMessage = msg.copyWith(status: types.Status.sending);
    _messages.replace(index, updateMessage);
    sdk.updateMessage(message);
  }

  @override
  void sendMessage(types.Message message) async {
    //ChatwootCallbacks? origional = (sdk as ChatwootSDK).callbacks;
    if (message is types.TextMessage) {
      types.TextMessage msg = message;
      _messages.add(message);
      sdk.addMessage(message);

      await _sdk.send(message);

      //chatwootClient!.sendMessage(content: msg.text, echoId: message.id);
      //widget.onSendPressed?.call(message);

    } else if (message is types.FileMessage) {
      _messages.insert(0, message);
      sdk.addMessage(message);
      //widget.onSendPressed?.call(message);
    } else if (message is types.ImageMessage) {
      _messages.insert(0, message);
      sdk.addMessage(message);
      //widget.onSendPressed?.call(message);
    } else {
      _messages.insert(0, message);
      sdk.addMessage(message);
      //widget.onSendPressed?.call(message);
    }
  }

  @override
  void beginTyping() {
    _typing.value = true;
  }

  @override
  void endTyping() {
    _typing.value = false;
  }

  @override
  Future<void> resolve() => Future.value();

  @override
  Future<void> more() => Future.delayed(const Duration(seconds: 1));
}
