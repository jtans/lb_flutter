import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lb_flutter/tv_list.dart';

/// LBLelinkPlayStatusUnkown = 0,    // 未知状态
/// LBLelinkPlayStatusLoading,       // 视频正在加载状态
/// LBLelinkPlayStatusPlaying,       // 正在播放状态
/// LBLelinkPlayStatusPause,         // 暂停状态
/// LBLelinkPlayStatusStopped,       // 退出播放状态
/// LBLelinkPlayStatusCommpleted,    // 播放完成状态
/// LBLelinkPlayStatusError,         // 播放错误
enum PlayStatus { unkown, loading, playing, pause, stoped, completed, error }

class Lblelinkplugin {
  static const MethodChannel _channel = const MethodChannel('lblelinkplugin');
  static const EventChannel _eventChannel =
      const EventChannel("lblelink_event");

  //设备列表回调
  static ValueChanged<List<TvData>>? _serviecListener;

  static Function? _connectListener;
  static Function? _disConnectListener;
  static LbCallBack? _lbCallBack;

  //public
  static StreamController<ProgressInfo> _progressStreamController =
      StreamController.broadcast();

  ///播放进度流
  static Stream<ProgressInfo> progressStream = _progressStreamController.stream;

  static StreamController<PlayStatus> _playStatusStreamController =
      StreamController();

  ///播放状态流
  static Stream<PlayStatus> playStatusStream =
      _playStatusStreamController.stream;

  static set lbCallBack(LbCallBack value) {
    _lbCallBack = value;
  } 

  static ProgressInfo? progressInfo;

  static ProgressInfo _getProgressInfo(bool isPlaying) {
    progressInfo?.isPlaying = isPlaying;
    if (progressInfo != null) {
      return progressInfo!;
    }
    return ProgressInfo.fromMap({'isPlaying': isPlaying});
  }

  ///eventChannel监听分发中心
  static eventChannelDistribution() {
    _eventChannel.receiveBroadcastStream().listen((data) {
      print(data);
      int type = data["type"];

      switch (type) {
        case -1:
          _lbCallBack?.disconnect();
          _disConnectListener?.call();
          break;
        case 0:
          TvListResult _tvList = TvListResult();
          _tvList.getResultFromMap(data["data"]);
          _serviecListener?.call(_tvList.tvList);
          break;
        case 1:
          _lbCallBack?.connectingCast();
          _connectListener?.call();
          break;
        case 2:
          _lbCallBack?.loadingCallBack();
          _progressStreamController
              .add(_getProgressInfo(false));
          _playStatusStreamController.add(PlayStatus.loading);
          break;
        case 3:
          _lbCallBack?.startCallBack();
          _progressStreamController
              .add(_getProgressInfo(true));
          _playStatusStreamController.add(PlayStatus.playing);
          break;
        case 4:
          Future.delayed(Duration(milliseconds: 500), () {
            //有什么办法处理？
            _lbCallBack?.pauseCallBack();
            _progressStreamController
                .add(_getProgressInfo(false));
            _playStatusStreamController.add(PlayStatus.pause);
          });
          break;
        case 5:
          _lbCallBack?.completeCallBack();
          _progressStreamController
              .add(_getProgressInfo(false));
          _playStatusStreamController.add(PlayStatus.completed);
          break;
        case 6:
          _lbCallBack?.stopCallBack();
          _progressStreamController
              .add(_getProgressInfo(false));
          _playStatusStreamController.add(PlayStatus.stoped);
          break;
        case 9:
          _lbCallBack?.errorCallBack(data["data"]);
          _progressStreamController
              .add(_getProgressInfo(false));
          _playStatusStreamController.add(PlayStatus.error);
          break;
        case 10:
          if (data["data"] is Map) {
            final info = data["data"];
            final progressInfo = ProgressInfo.fromMap({
              'current': info['current'],
              'duration': info['duration'],
              'isPlaying': true
            });
            Lblelinkplugin.progressInfo = progressInfo;
            //通知流变更
            _progressStreamController.add(progressInfo);
            //通知回调变更
            _lbCallBack?.playingCallBack(progressInfo);
          }
          break;
        case 11:
          _lbCallBack?.connectSuccess(data["data"].toString());
          break;
      }
    });
  }

  ///初始化sdk
  ///返回值：初始化成功与否
  static Future<bool> initLBSdk(String appid, String secretKey) async {
    //初始化的时候注册eventChannel回调
    eventChannelDistribution();
    return _channel.invokeMethod(
        "initLBSdk", {"appid": appid, "secretKey": secretKey}).then((data) {
      return data;
    });
  }

  ///log开关
  static void enableLog(bool enable) {
    if (Platform.isIOS) {
      _channel.invokeMethod('enableLog', {"data": enable});
    }
  }

  ///获取设备列表
  ///回调：设备数组
  static getServicesList(ValueChanged<List<TvData>> serviecListener) {
    //开始搜索设备
    _channel.invokeMethod("beginSearchEquipment");

    _serviecListener = serviecListener;

//    _eventChannel.receiveBroadcastStream().listen((data) {
//
//      List<String> result = [];
//      data.forEach((data) {
//        String name = data as String;
//        result.add(name);
//      });
//        messageListener(result);
//    });
  }

  ///连接设备(参数未定)
  static connectToService(String ipAddress, String name,
      {required Function fConnectListener,
      required Function fDisConnectListener}) {
    _connectListener = fConnectListener;
    _disConnectListener = fDisConnectListener;
    _lbCallBack?.connectingCast();
    _channel.invokeMethod(
        "connectToService", {"ipAddress": ipAddress, "name": name});
  }

  ///获取上次连接的设备
  static Future<TvData> getLastConnectService() {
    return _channel.invokeMethod("getLastConnectService").then((data) {
      print("data is $data");

      if (data == null) {
        return data;
      }

      return TvData()
        ..uId = data["tvUID"]
        ..name = data["tvName"]
        ..ipAddress = data["ipAddress"];
    });
  }

  ///断开连接
  static disConnect() {
    _channel.invokeMethod("disConnect");
//        .then((data){
//      if(data == 0){
//        _disConnectListener.call();
//      }
//    });
  }

  ///暂停
  static pause() {
    _channel.invokeMethod("pause");
  }

  ///继续播放
  static resumePlay() {
    _channel.invokeMethod("resumePlay");
  }

  ///退出播放
  static stop() {
    _channel.invokeMethod("stop");
  }

  ///播放
  static play(String playUrlString, {int position = 0, int type = 102}) {
    _channel.invokeMethod("play", {
      "playUrlString": playUrlString,
      "startPosition": position,
      "playType": type
    });
  }

  ///调节进度的位置，单位秒
  static seekTo(int seekTime) {
     _channel.invokeMethod("seekTo", {
      "seekTime": seekTime,
    });
  }

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}

abstract class LbCallBack {
  void startCallBack() {}

  void loadingCallBack() {}

  void completeCallBack() {}

  void pauseCallBack() {}

  void stopCallBack() {}

  void errorCallBack(String errorDes) {}

  void playingCallBack(ProgressInfo data) {}

  void connectSuccess(String playerInfo) {}

  void connectingCast() {}

  void disconnect() {}
}
