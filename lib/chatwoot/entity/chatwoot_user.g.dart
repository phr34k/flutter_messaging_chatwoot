// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chatwoot_user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatwootUserAdapter extends TypeAdapter<ChatwootUser> {
  @override
  final int typeId = 3;

  @override
  ChatwootUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatwootUser(
      identifier: fields[0] as String?,
      identifierHash: fields[1] as String?,
      name: fields[2] as String?,
      email: fields[3] as String?,
      avatarUrl: fields[4] as String?,
      customAttributes: fields[5] as dynamic,
    );
  }

  @override
  void write(BinaryWriter writer, ChatwootUser obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.identifier)
      ..writeByte(1)
      ..write(obj.identifierHash)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.avatarUrl)
      ..writeByte(5)
      ..write(obj.customAttributes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatwootUserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatwootUser _$ChatwootUserFromJson(Map<String, dynamic> json) {
  return ChatwootUser(
    identifier: json['identifier'] as String?,
    identifierHash: json['identifierHash'] as String?,
    name: json['name'] as String?,
    email: json['email'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    customAttributes: json['custom_attributes'],
  );
}

Map<String, dynamic> _$ChatwootUserToJson(ChatwootUser instance) =>
    <String, dynamic>{
      'identifier': instance.identifier,
      'identifierHash': instance.identifierHash,
      'name': instance.name,
      'email': instance.email,
      'avatar_url': instance.avatarUrl,
      'custom_attributes': instance.customAttributes,
    };
