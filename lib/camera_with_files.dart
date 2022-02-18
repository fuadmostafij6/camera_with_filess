// ignore_for_file: unnecessary_null_comparison

library camera_with_files;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sliding_up_panel/flutter_sliding_up_panel.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_gallery/photo_gallery.dart';

class CameraApp extends StatefulWidget {
  final bool isMultiple;

  const CameraApp({Key? key, this.isMultiple = false}) : super(key: key);

  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  CameraController? controller;
  late List<CameraDescription> cameras;
  List<Album> imageAlbums = [];
  Set<Medium> imageMedium = {};
  late Uint8List bytes;
  List<File> results = [];
  List<int> indexList = [];
  bool flashOn = false;
  int camIndex = 0;
  bool showPerformance = false;
  late double width;

  ///The controller of sliding up panel
  SlidingUpPanelController panelController = SlidingUpPanelController();

  @override
  void initState() {
    super.initState();
    cameraLoad();
  }

  cameraLoad() async {
    cameras = await availableCameras();
    controller = CameraController(cameras[0], ResolutionPreset.max);
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
  }

  Future<bool> _promptPermissionSetting() async {
    if (Platform.isIOS &&
            await Permission.storage.request().isGranted &&
            await Permission.photos.request().isGranted ||
        Platform.isAndroid && await Permission.storage.request().isGranted) {
      return true;
    }
    return false;
  }

  loadImages() async {
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
    return Stack(
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

                    Navigator.pop(context, results);
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
              Transform.scale(
                scale: scale,
                child: Center(
                  child: CameraPreview(controller!),
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
                                panelController.expand();
                                //print(detalis.primaryVelocity);
                              },
                              onTap: () {
                                panelController.expand();
                              },
                              child: const Icon(
                                Icons.arrow_drop_up_outlined,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children:
                                  List.generate(imageMedium.length, (index) {
                                if (bytes == null) {
                                  return Container();
                                }
                                return GestureDetector(
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
                                      Navigator.pop(context, [file]);
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
                                        margin: const EdgeInsets.only(left: 2),
                                        child: FadeInImage(
                                          fit: BoxFit.cover,
                                          placeholder: MemoryImage(bytes),
                                          image: ThumbnailProvider(
                                              mediumId: imageMedium
                                                  .elementAt(index)
                                                  .id,
                                              mediumType: MediumType.image,
                                              width: 128,
                                              height: 128,
                                              highQuality: true),
                                        ),
                                      ),
                                      if (indexList.contains(index))
                                        Container(
                                          width: 80,
                                          height: 80,
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
                            GestureDetector(
                              onTap: () async {
                                XFile file2 = await controller!.takePicture();
                                File file = File(file2.path);
                                Uint8List dataFile = await file.readAsBytes();
                                String fileName = DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString();
                                await ImageGallerySaver.saveImage(dataFile,
                                    quality: 100,
                                    name: fileName + ".jpg",
                                    isReturnImagePathOfIOS: true);
                                Navigator.pop(context, [file]);
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
                            (cameras.length > 1)
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
                                : Container(),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
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
                                      Navigator.pop(context, results);
                                    },
                                    child: const Text(
                                      "Done",
                                      style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : Container(),
                            // TextButton(
                            //     onPressed: () async {
                            //
                            //     },
                            //     child: const Text("OK"))
                          ],
                        ),
                      ),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10.0,
                          mainAxisSpacing: 10.0,
                          shrinkWrap: true,
                          children: List.generate(
                              imageMedium.length,
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
                                      Navigator.pop(context, [file]);
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
                                      margin: const EdgeInsets.only(left: 2),
                                      child: FadeInImage(
                                        fit: BoxFit.cover,
                                        placeholder: MemoryImage(bytes),
                                        image: ThumbnailProvider(
                                            mediumId:
                                                imageMedium.elementAt(index).id,
                                            mediumType: MediumType.image,
                                            highQuality: true),
                                      ),
                                    ),
                                    if (indexList.contains(index))
                                      Container(
                                        margin: const EdgeInsets.only(left: 2),
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
    );
  }

  onSettingCallback() {
    setState(() {
      showPerformance = !showPerformance;
    });
  }
}
