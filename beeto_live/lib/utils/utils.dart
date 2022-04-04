import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:handy_toast/handy_toast.dart';
import 'package:rongcloud_rtc_wrapper_plugin/rongcloud_rtc_wrapper_plugin.dart';
import 'package:beeto_live/data/data.dart';
import 'package:beeto_live/frame/ui/loading.dart';
import 'package:beeto_live/frame/utils/extension.dart';

class Utils {
  static String generateRoomId() {
    int current = _random.nextInt(1000000);
    return '$current'.padLeft(6, '0');
  }

  static set engine(RCRTCEngine? engine) {
    _engine = engine;
    _onSetEngine();
  }

  static void _onSetEngine() {
    if (_engine != null) {
      _engine?.onSubRoomBanded = (String roomId) {
        if (_bandedSubRooms.indexOf(roomId) < 0) {
          _bandedSubRooms.add(roomId);
        }
      };
      _engine?.onSubRoomDisband = (String roomId, String userId) {
        _joinedSubRooms.remove(roomId);
        _bandedSubRooms.remove(roomId);
      };
      _engine?.onUserJoined = (String roomId, String userId) {
        _users.removeWhere((user) => user.id == userId);
        _users.add(UserState(roomId, userId));
        onUserListChanged?.call();
      };
      _engine?.onUserOffline = (String roomId, String userId) {
        _users.removeWhere((user) => user.id == userId);
        onUserListChanged?.call();
        onRemoveUserAudio?.call(userId);
      };
      _engine?.onUserLeft = (String roomId, String userId) {
        _users.removeWhere((user) => user.id == userId);
        onUserListChanged?.call();
        onRemoveUserAudio?.call(userId);
      };
      _engine?.onRemotePublished = (String roomId, String userId, RCRTCMediaType type) {
        UserState? user = _users.firstWhereOrNull((user) => user.id == userId);
        switch (type) {
          case RCRTCMediaType.audio:
            user?.audioPublished = true;
            onUserAudioStateChanged?.call(userId, true);
            break;
          case RCRTCMediaType.video:
            user?.videoPublished = true;
            onUserVideoStateChanged?.call(userId, true);
            break;
          case RCRTCMediaType.audio_video:
            user?.audioPublished = true;
            user?.videoPublished = true;
            onUserAudioStateChanged?.call(userId, true);
            onUserVideoStateChanged?.call(userId, true);
            break;
        }
      };
      _engine?.onRemoteUnpublished = (String roomId, String userId, RCRTCMediaType type) {
        UserState? user = _users.firstWhereOrNull((user) => user.id == userId);
        switch (type) {
          case RCRTCMediaType.audio:
            user?.audioPublished = false;
            user?.audioSubscribed = false;
            onUserAudioStateChanged?.call(userId, false);
            onRemoveUserAudio?.call(userId);
            break;
          case RCRTCMediaType.video:
            user?.videoPublished = false;
            user?.videoSubscribed = false;
            onUserVideoStateChanged?.call(userId, false);
            break;
          case RCRTCMediaType.audio_video:
            user?.audioPublished = false;
            user?.videoPublished = false;
            user?.audioSubscribed = false;
            user?.videoSubscribed = false;
            onUserAudioStateChanged?.call(userId, false);
            onUserVideoStateChanged?.call(userId, false);
            onRemoveUserAudio?.call(userId);
            break;
        }
      };
      _engine?.onRemoteCustomStreamPublished = (String roomId, String userId, String tag, RCRTCMediaType type) {
        UserState? user = _users.firstWhereOrNull((user) => user.id == userId);
        int index = user?.customs.indexWhere((custom) => custom.tag == tag) ?? -1;
        CustomState state = index > -1 ? user!.customs[index] : CustomState(tag);
        switch (type) {
          case RCRTCMediaType.audio:
            state.audioPublished = true;
            break;
          case RCRTCMediaType.video:
            state.videoPublished = true;
            break;
          case RCRTCMediaType.audio_video:
            state.audioPublished = true;
            state.videoPublished = true;
            break;
        }
        if (index < 0) {
          user?.customs.add(state);
        }
        onUserCustomStateChanged?.call(userId, tag, state.audioPublished, state.videoPublished);
      };
      _engine?.onRemoteCustomStreamUnpublished = (String roomId, String userId, String tag, RCRTCMediaType type) {
        UserState? user = _users.firstWhereOrNull((user) => user.id == userId);
        int index = user?.customs.indexWhere((custom) => custom.tag == tag) ?? -1;
        if (index < 0) return;
        CustomState state = user!.customs[index];
        switch (type) {
          case RCRTCMediaType.audio:
            state.audioPublished = false;
            state.audioSubscribed = false;
            onRemoveUserAudio?.call('$userId@$tag');
            break;
          case RCRTCMediaType.video:
            state.videoPublished = false;
            state.videoSubscribed = false;
            break;
          case RCRTCMediaType.audio_video:
            state.audioPublished = false;
            state.videoPublished = false;
            state.audioSubscribed = false;
            state.videoSubscribed = false;
            onRemoveUserAudio?.call('$userId@$tag');
            break;
        }
        if (!state.audioPublished && !state.videoPublished) {
          user.customs.removeAt(index);
        }
        onUserCustomStateChanged?.call(userId, tag, state.audioPublished, state.videoPublished);
      };
    } else {
      onUserListChanged = null;
      onUserAudioStateChanged = null;
      onUserVideoStateChanged = null;
      onUserCustomStateChanged = null;
      _engine?.onUserJoined = null;
      _engine?.onUserOffline = null;
      _engine?.onUserLeft = null;
      _engine?.onRemotePublished = null;
      _engine?.onRemoteUnpublished = null;
      _engine?.onRemoteCustomStreamPublished = null;
      _engine?.onRemoteCustomStreamUnpublished = null;
      _users.clear();
      _bandedSubRooms.clear();
      _joinedSubRooms.clear();
    }
  }

  static void joinSubRoom(BuildContext context, String roomId) async {
    Loading.show(context);
    _engine?.onSubRoomJoined = (roomId, code, message) {
      _engine?.onSubRoomJoined = null;
      Loading.dismiss(context);
      if (code != 0) {
        '加入$roomId子房间失败, code:$code, message:$message'.toast();
      } else {
        _joinedSubRooms.add(roomId);
        '加入$roomId子房间成功'.toast();
      }
    };
    int code = await _engine?.joinSubRoom(roomId) ?? -1;
    if (code != 0) {
      _engine?.onSubRoomJoined = null;
      Loading.dismiss(context);
      '加入$roomId子房间失败, code:$code'.toast();
    }
  }

  static void clearRoomUser(String roomId, bool disband) {
    if (disband) _bandedSubRooms.remove(roomId);
    _joinedSubRooms.remove(roomId);
    users.removeWhere((user) => user.room == roomId);
    onUserListChanged?.call();
  }

  static RCRTCEngine? get engine {
    return _engine;
  }

  static List<UserState> get users => _users;

  static List<String> get joinedSubRooms => _joinedSubRooms;

  static List<String> get joinableSubRooms {
    List<String> list = [];
    list.addAll(_bandedSubRooms);
    _joinedSubRooms.forEach((roomId) {
      list.remove(roomId);
    });
    return list;
  }

  static Random _random = Random.secure();

  static RCRTCEngine? _engine;

  static Function()? onUserListChanged;
  static Function(String id)? onRemoveUserAudio;
  static Function(String id, bool published)? onUserAudioStateChanged;
  static Function(String id, bool published)? onUserVideoStateChanged;
  static Function(String id, String tag, bool audio, bool video)? onUserCustomStateChanged;

  static List<UserState> _users = [];

  static List<String> _bandedSubRooms = [];
  static List<String> _joinedSubRooms = [];
}
