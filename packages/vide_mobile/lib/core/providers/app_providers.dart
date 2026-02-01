import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'app_providers.g.dart';

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) async {
  return await SharedPreferences.getInstance();
}

@riverpod
Stream<ConnectivityResult> connectivity(Ref ref) {
  // connectivity_plus v5.x returns Stream<ConnectivityResult>
  return Connectivity().onConnectivityChanged;
}

@riverpod
Future<ConnectivityResult> currentConnectivity(Ref ref) async {
  // connectivity_plus v5.x returns ConnectivityResult
  return await Connectivity().checkConnectivity();
}
