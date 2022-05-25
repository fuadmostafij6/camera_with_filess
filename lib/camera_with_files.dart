library camera_with_files;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_sliding_up_panel/flutter_sliding_up_panel.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_gallery/photo_gallery.dart';
import 'package:image_picker/image_picker.dart';
import "package:intl/intl.dart";
import 'package:path_provider/path_provider.dart';

class CameraApp extends StatefulWidget {
  final bool isMultiple;
  final bool isSimpleUI;
  int? compressionQuality;
  int? compressedSize;

  CameraApp(
      {Key? key,
      this.isMultiple = false,
      this.isSimpleUI = true,
      this.compressedSize,
      this.compressionQuality = 100})
      : super(key: key);

  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  CameraController? controller;
  late List<CameraDescription> cameras;
  List<Album> imageAlbums = [];
  Set<Medium> imageMedium = {};
  Uint8List? bytes;
  List<File> results = [];
  List<int> indexList = [];
  bool flashOn = false;
  int camIndex = 0;
  bool showPerformance = false;
  late double width;
  int pageIndex = 1;
  int pageCount = 10;
  int pageIndex2 = 1;
  int pageCount2 = 50;

  int count = 0;
  int count2 = 0;
  ScrollController bottomController = ScrollController();
  ScrollController topController = ScrollController();
  int scroll = 0;

  ///The controller of sliding up panel
  SlidingUpPanelController panelController = SlidingUpPanelController();

  @override
  void initState() {
    super.initState();
    cameraLoad();
  }

  cameraLoad() async {
    cameras = await availableCameras();
    controller = CameraController(cameras[0], ResolutionPreset.max,
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : null);
    controller!.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _promptPermissionSetting().then((_) {
        if (_) {
          loadImages();
        }
        setState(() {});
      });

      setState(() {});
    });
    bottomController.addListener(() {
      if (bottomController.position.atEdge) {
        bool isTop = bottomController.position.pixels == 0;
        if (!isTop) {
          if (imageMedium.length > (pageCount2 * pageIndex2)) {
            setState(() {
              pageIndex2++;
            });
            if (pageCount2 * (pageIndex2) > imageMedium.length) {
              //fix here
              count2 = imageMedium.length;
            } else {
              count2 = pageCount2 * pageIndex2;
            }
          }
        }
      }
    });
    topController.addListener(() {
      if (topController.position.atEdge) {
        bool isTop = topController.position.pixels == 0;
        if (!isTop) {
          if (imageMedium.length > (pageCount * pageIndex)) {
            setState(() {
              pageIndex++;
            });
            if (pageCount * (pageIndex) > imageMedium.length) {
              //fix here
              count = imageMedium.length;
            } else {
              count = pageCount * pageIndex;
            }
          }
        }
      }
    });
  }

  Future<bool> _promptPermissionSetting() async {
    if (kIsWeb) {
      return true;
    } else if (Platform.isIOS) {
      PermissionStatus status = await Permission.storage.request();
      PermissionStatus status2 = await Permission.photos.request();
      PermissionStatus status3 = await Permission.mediaLibrary.request();
      return status.isGranted && status2.isGranted && status3.isGranted;
    } else if (Platform.isAndroid) {
      PermissionStatus status = await Permission.storage.request();
      return status.isGranted;
    }
    return false;
  }

  loadImages() async {
    if (kIsWeb) {
      return;
    }
    imageAlbums = await PhotoGallery.listAlbums(
      mediumType: MediumType.image,
    );
    imageMedium = {};
    for (var element in imageAlbums) {
      var data = await element.listMedia();
      imageMedium.addAll(data.items);
    }
    var dataB = await rootBundle.load('assets/ss.png');
    bytes = dataB.buffer.asUint8List(dataB.offsetInBytes, dataB.lengthInBytes);
    if (pageCount2 * (pageIndex2) > imageMedium.length) {
      //fix here
      count2 = imageMedium.length;
    } else {
      count2 = pageCount2 * (pageIndex2);
    }
    if (pageCount * (pageIndex) > imageMedium.length) {
      //fix here
      count = imageMedium.length;
    } else {
      count = pageCount * (pageIndex);
    }
    setState(() {});
  }

  @override
  void dispose() {
    controller!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return Container();
    }
    var camera = controller!.value;
    final size = MediaQuery.of(context).size;
    var scale = 0.0;
    try {
      scale = size.aspectRatio * camera.aspectRatio;
    } catch (e) {
      debugPrint(e.toString());
    }

    if (scale < 1) scale = 1 / scale;

    if (!controller!.value.isInitialized) {
      return Container();
    }
    return WillPopScope(
      onWillPop: () {
        if (panelController.status == SlidingUpPanelStatus.expanded) {
          panelController.hide();
          return Future.value(false);
        }
        return Future.value(true);
      },
      child: Stack(
        children: [
          Scaffold(
            floatingActionButton: indexList.isNotEmpty
                ? FloatingActionButton(
                    onPressed: () async {
                      for (var element in indexList) {
                        File file =
                            await imageMedium.elementAt(element).getFile();
                        setState(() {
                          results.add(file);
                        });
                      }
                      compress(results);
                    },
                    backgroundColor: Colors.greenAccent,
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                    ),
                  )
                : null,
            body: Stack(
              children: [
                GestureDetector(
                  // onHorizontalDragStart: (detalis) {
                  //   panelController.expand();
                  //   //print(detalis.primaryVelocity);
                  // },
                  onVerticalDragStart: (e) {
                    panelController.expand();
                  },
                  child: Transform.scale(
                    scale: scale,
                    child: Center(
                      child: CameraPreview(controller!),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    height: 190,
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        Column(
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width,
                              child: GestureDetector(
                                onHorizontalDragStart: (detalis) {
                                  if (kIsWeb) {
                                    return;
                                  }
                                  panelController.expand();
                                  //print(detalis.primaryVelocity);
                                },
                                onTap: () async {
                                  if (kIsWeb) {
                                    final ImagePicker _picker = ImagePicker();
                                    if (widget.isMultiple) {
                                      List<XFile>? images =
                                          await _picker.pickMultiImage();
                                      List<File> file = [];
                                      for (var element in images!) {
                                        file.add(File(element.path));
                                      }
                                      compress(file);
                                    } else {
                                      XFile? image = await _picker.pickImage(
                                          source: ImageSource.gallery);
                                      File file = File(image!.path);
                                      compress([file]);
                                    }
                                    return;
                                  }
                                  panelController.expand();
                                },
                                child: const Icon(
                                  Icons.arrow_drop_up_outlined,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (!kIsWeb)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                controller: topController,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: List.generate(count, (index) {
                                    if (bytes == null) {
                                      return Container();
                                    }
                                    return GestureDetector(
                                      onVerticalDragStart: (detalis) {
                                        panelController.expand();
                                        //print(detalis.primaryVelocity);
                                      },
                                      onLongPress: () async {
                                        if (!widget.isMultiple) {
                                          return;
                                        }

                                        if (indexList.contains(index)) {
                                          setState(() {
                                            indexList.remove(index);
                                          });
                                        } else {
                                          setState(() {
                                            indexList.add(index);
                                          });
                                        }
                                      },
                                      onTap: () async {
                                        if (indexList.isEmpty) {
                                          File file = await imageMedium
                                              .elementAt(index)
                                              .getFile();
                                          compress([file]);
                                        } else {
                                          if (indexList.contains(index)) {
                                            setState(() {
                                              indexList.remove(index);
                                            });
                                          } else {
                                            setState(() {
                                              indexList.add(index);
                                            });
                                          }
                                        }
                                      },
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: 80,
                                            height: 80,
                                            margin:
                                                const EdgeInsets.only(left: 2),
                                            child: FadeInImage(
                                                fit: BoxFit.cover,
                                                placeholder:
                                                    MemoryImage(bytes!),
                                                image: ThumbnailProvider(
                                                    mediumId: imageMedium
                                                        .elementAt(index)
                                                        .id,
                                                    mediumType:
                                                        MediumType.image,
                                                    width: 128,
                                                    height: 128,
                                                    highQuality: false)),
                                          ),
                                          if (indexList.contains(index))
                                            Container(
                                              width: 80,
                                              height: 80,
                                              margin: const EdgeInsets.only(
                                                  left: 2),
                                              color:
                                                  Colors.grey.withOpacity(0.4),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            )
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ),
                          ],
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              (!kIsWeb)
                                  ? IconButton(
                                      onPressed: () async {
                                        final ImagePicker _picker =
                                            ImagePicker();
                                        if (!widget.isMultiple) {
                                          final XFile? image =
                                              await _picker.pickImage(
                                                  source: ImageSource.gallery);
                                          if (image == null) {
                                            return;
                                          }
                                          File file = File(image.path);
                                          compress([file]);
                                        } else {
                                          final List<XFile>? images =
                                              await _picker.pickMultiImage();
                                          if (images == null) {
                                            return;
                                          }
                                          List<File> file = [];
                                          for (var element in images) {
                                            file.add(File(element.path));
                                          }
                                          compress(file);
                                        }
                                      },
                                      icon: const Icon(Icons.file_open,
                                          size: 30, color: Colors.white))
                                  : Container(),
                              GestureDetector(
                                onTap: () async {
                                  XFile file2 = await controller!.takePicture();
                                  File file = File(file2.path);
                                  if (!kIsWeb) {
                                    Uint8List dataFile =
                                        await file.readAsBytes();
                                    String fileName = DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString();
                                    await ImageGallerySaver.saveImage(dataFile,
                                        quality: 100,
                                        name: fileName + ".jpg",
                                        isReturnImagePathOfIOS: true);
                                  }
                                  compress([file]);
                                },
                                child: Container(
                                  width: 75,
                                  height: 75,
                                  decoration: BoxDecoration(
                                      // color: Colors.white,
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(
                                              50) //                 <--- border radius here
                                          ),
                                      border: Border.all(
                                          color: Colors.white, width: 3)),
                                ),
                              ),
                              (!kIsWeb && (cameras.length > 1))
                                  ? IconButton(
                                      onPressed: () {
                                        if (camIndex + 1 >= cameras.length) {
                                          camIndex = 0;
                                        } else {
                                          camIndex++;
                                        }
                                        controller = CameraController(
                                            cameras[camIndex],
                                            ResolutionPreset.veryHigh);
                                        controller!.initialize().then((_) {
                                          if (!mounted) {
                                            return;
                                          }
                                          setState(() {});
                                        });
                                      },
                                      icon: const Icon(
                                          Icons.cameraswitch_outlined,
                                          size: 30,
                                          color: Colors.white))
                                  : Container()
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                      alignment: Alignment.topCenter,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                              onPressed: () {
                                setState(() {
                                  flashOn = !flashOn;
                                  if (flashOn) {
                                    controller!.setFlashMode(FlashMode.torch);
                                  } else {
                                    controller!.setFlashMode(FlashMode.off);
                                  }
                                });
                              },
                              icon: const Icon(Icons.flash_off,
                                  size: 30, color: Colors.white)),
                          IconButton(
                              onPressed: () {
                                compress([]);
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ))
                        ],
                      )),
                ),
              ],
            ),
          ),
          SlidingUpPanelWidget(
            child: imageAlbums.isEmpty
                ? Container()
                : Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        Container(
                          width: size.width,
                          height: 50,
                          padding: const EdgeInsets.only(left: 20, right: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              indexList.isNotEmpty
                                  ? Text(
                                      indexList.length.toString() + " Selected")
                                  : const Text("Please Choose Images"),
                              widget.isMultiple && indexList.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () async {
                                        for (var element in indexList) {
                                          File file = await imageMedium
                                              .elementAt(element)
                                              .getFile();
                                          setState(() {
                                            results.add(file);
                                          });
                                        }
                                        compress(results);
                                      },
                                      child: const Text(
                                        "Done",
                                        style: TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  : Container(),
                            ],
                          ),
                        ),
                        Expanded(
                          child: NotificationListener(
                            onNotification: (t) {
                              if (t is ScrollEndNotification) {
                                if (bottomController.position.pixels == 0.0) {
                                  scroll++;
                                  print(scroll);
                                  if (scroll.isOdd) {
                                    print(scroll);
                                    panelController.collapse();
                                    scroll = 1;
                                  }
                                }
                                print(bottomController.position.pixels);
                                return true;
                              }
                              return false;
                            },
                            child: GridView.count(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10.0,
                              mainAxisSpacing: 10.0,
                              controller: bottomController,
                              shrinkWrap: true,
                              children: List.generate(
                                  count2,
                                  (index) => GestureDetector(
                                      onLongPress: () async {
                                        if (!widget.isMultiple) {
                                          return;
                                        }
                                        if (indexList.contains(index)) {
                                          setState(() {
                                            indexList.remove(index);
                                          });
                                        } else {
                                          setState(() {
                                            indexList.add(index);
                                          });
                                        }
                                      },
                                      onTap: () async {
                                        if (indexList.isEmpty) {
                                          File file = await imageMedium
                                              .elementAt(index)
                                              .getFile();
                                          compress([file]);
                                        } else {
                                          if (indexList.contains(index)) {
                                            setState(() {
                                              indexList.remove(index);
                                            });
                                          } else {
                                            setState(() {
                                              indexList.add(index);
                                            });
                                          }
                                        }
                                      },
                                      child: Stack(children: [
                                        Container(
                                          width: size.width / 4,
                                          height: size.width / 4,
                                          margin:
                                              const EdgeInsets.only(left: 2),
                                          child: FadeInImage(
                                            fit: BoxFit.cover,
                                            placeholder: MemoryImage(bytes!),
                                            image: ThumbnailProvider(
                                                mediumId: imageMedium
                                                    .elementAt(index)
                                                    .id,
                                                mediumType: MediumType.image,
                                                highQuality: false),
                                          ),
                                        ),
                                        if (indexList.contains(index))
                                          Container(
                                            margin:
                                                const EdgeInsets.only(left: 2),
                                            color: Colors.grey.withOpacity(0.4),
                                            child: const Center(
                                              child: Icon(
                                                Icons.check,
                                                color: Colors.white,
                                              ),
                                            ),
                                          )
                                      ]))),
                            ),
                          ),
                        ),
                      ],
                    )),
            controlHeight: 0.0,
            anchor: 0.0,
            panelController: panelController,
            dragDown: (details) {
              debugPrint("Drag Down");
            },
            dragStart: (details) {
              debugPrint('dragStart');
            },
            dragCancel: () {
              debugPrint('dragCancel');
            },
            dragUpdate: (details) {
              double x = details.localPosition.dx;
              debugPrint(x.toString());
              debugPrint(
                  'dragUpdate,${panelController.status == SlidingUpPanelStatus.dragging ? 'dragging' : ''}');
            },
            dragEnd: (details) {
              debugPrint('dragEnd');
            },
          ),
        ],
      ),
    );
  }

  onSettingCallback() {
    setState(() {
      showPerformance = !showPerformance;
    });
  }

  compress(List<File> files) async {
    List<File> files2 = [];
    for (File file in files) {
      Uint8List? blobBytes = await testCompressFile(file);
      var dir = await getTemporaryDirectory();
      String trimmed = dir.absolute.path;
      String dateTimeString =
          dateTimeToString(DateTime.now(), "dd-yyyy-MMM HH:mm a");
      String pathString = trimmed + "/" + dateTimeString + ".jpg";
      File fileNew = File(pathString);
      fileNew.writeAsBytesSync(List.from(blobBytes!));
      files2.add(fileNew);
    }

    Navigator.pop(context, files2);
  }

  String dateTimeToString(DateTime dateTime, String pattern) {
    final format = DateFormat(pattern);
    return format.format(dateTime);
  }

  Future<Uint8List?> testCompressFile(File file) async {
    // int quality = widget.compressionQuality!;
    var decodedImage = await decodeImageFromList(file.readAsBytesSync());
    // if (widget.compressedSize != null) {
    //   int size = await file.length();
    //   int qualitySize = widget.compressedSize!;
    //   if (size > qualitySize) {
    //     quality = (qualitySize / size * 100).ceil();
    //   }
    // }
    var result = await FlutterImageCompress.compressWithFile(file.absolute.path,
        minHeight: decodedImage.height,
        minWidth: decodedImage.width,
        quality: widget.compressionQuality!);

    // int size = await file.length();
    // print("Original Size");
    // print(size);
    return result;
  }
}
