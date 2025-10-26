import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_storage/get_storage.dart';

// ✅ Exports
final FirebaseFirestore firestore = FirebaseFirestore.instance;
final FirebaseStorage storage = FirebaseStorage.instance;
final GetStorage userStorage = GetStorage();

List<CameraDescription> cameras = <CameraDescription>[];
List commonContactsList = [];
List sentRequestList = [];
List receivedRequestList = [];
