import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:sweep/classes/post.dart';
import 'package:sweep/pages/post_page/post_image_preview_page.dart';
import 'package:sweep/pages/post_page/post_map_preview_page.dart';
import 'package:sweep/states/image_notifier.dart';
import 'package:sweep/states/location_notifier.dart';
import 'package:sweep/states/post_notifier.dart';
import 'package:sweep/states/profile_provider.dart';
import 'package:sweep/widgets/currentLocationContainer.dart';
import 'package:sweep/widgets/post_margin.dart';

class PostPage extends StatefulHookConsumerWidget {
  const PostPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _PostPageState();
}

class _PostPageState extends ConsumerState<PostPage>
    with TickerProviderStateMixin {
  late AnimatedMapController mapController;

  @override
  void initState() {
    super.initState();
    mapController = AnimatedMapController(vsync: this);
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagePaths = useState([ref.watch(imagePathProvider)]);
    final textController = useState(TextEditingController());
    final postTime = useState(DateTime.now());
    final segmentedButtonSelected = useState({PostType.trash});
    final currentLocation = ref.watch(locationProvider);

    final postData = useState(
      Post(
        // 現在の画像
        imagePaths: imagePaths.value,
        // 現在地
        location: currentLocation,
        // 空白
        comment: "",
        // 0
        point: 0,
        // 現在時刻
        time: postTime.value,
        // 0
        nice: 0,
        // タイプを指定
        type: segmentedButtonSelected.value.first,
        // uid取得,
        uid: ref.watch(profileProvider)!.uid,
      ),
    );

    useEffect(() {
      postData.value = postData.value.copyWith(location: currentLocation);

      return null;
    }, [currentLocation]);

    useEffect(() {
      textController.value.text = postData.value.comment;
      ref.read(locationProvider.notifier).getCurrentLocation();

      return () {
        textController.dispose();
      };
    }, []);

    return SingleChildScrollView(
      child: Column(
        spacing: 8,
        mainAxisSize: MainAxisSize.max,
        children: [
          SegmentedButton(
            selected: segmentedButtonSelected.value,
            onSelectionChanged: (selected) {
              segmentedButtonSelected.value = selected;
            },
            segments: [
              ButtonSegment(
                  label: Text("ゴミ".padLeft(3, "　")), value: PostType.trash),
              ButtonSegment(label: Text("ゴミ箱"), value: PostType.trashCan),
            ],
          ),
          SizedBox(
            height: 300,
            width: double.infinity,
            child: CarouselView.weighted(
              itemSnapping: true,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              onTap: (index) async {
                if (index < imagePaths.value.length) {
                  imagePaths.value = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ImagePreviewPage(
                        imagePaths: imagePaths.value,
                        index: index,
                      ),
                    ),
                  );
                } else {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return SimpleDialog(
                        children: [
                          ListTile(
                            onTap: () async {
                              if (await ref
                                  .read(imagePathProvider.notifier)
                                  .pickImageFromGallery()) {
                                imagePaths.value
                                    .add(ref.watch(imagePathProvider));
                              }
                              Navigator.of(context).pop();
                            },
                            title: Text("ギャラリーから選択"),
                          ),
                          ListTile(
                            onTap: () async {
                              if (await ref
                                  .read(imagePathProvider.notifier)
                                  .pickImageFromCamera()) {
                                imagePaths.value
                                    .add(ref.watch(imagePathProvider));
                              }
                              Navigator.of(context).pop();
                            },
                            title: Text("カメラで撮影"),
                          ),
                        ],
                      );
                    },
                  );
                }
              },
              flexWeights: [8, 2],
              children: List.generate(
                imagePaths.value.length + 1,
                (index) {
                  if (index < imagePaths.value.length) {
                    return Image.file(
                      File(imagePaths.value[index]),
                      fit: BoxFit.cover,
                    );
                  } else {
                    return Center(
                      child: IconButton.filled(
                          onPressed: () {}, icon: Icon(Icons.add)),
                    );
                  }
                },
              ),
            ),
          ),
          PostMargin(
            child: TextField(
              controller: textController.value,
              maxLength: 140,
              maxLines: 2,
              minLines: 1,
              decoration:
                  InputDecoration(hintText: "コメント", border: InputBorder.none),
            ),
          ),
          PostMargin(
            child: ListTile(
              onTap: () async {
                final LatLng? result = await showModalBottomSheet(
                  showDragHandle: true,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  context: context,
                  builder: (context) {
                    return MapPreviewPage(
                      controller: mapController,
                      currentLocation: currentLocation,
                    );
                  },
                );
                if (result != null) {
                  postData.value = postData.value.copyWith(location: result);
                }
              },
              leading: Icon(Icons.pin_drop_rounded),
              title: (currentLocation == postData.value.location)
                  ? Text("現在地")
                  : Text("選択した地点"),
              trailing: Icon(Icons.arrow_forward_rounded),
            ),
          ),
          PostMargin(
            child: ListTile(
              onTap: () async {
                DateTime? tempDate;
                TimeOfDay? tempTime;
                tempDate = await showDatePicker(
                  context: context,
                  firstDate: postData.value.time.add(Duration(days: -31)),
                  lastDate: postData.value.time.add(
                    Duration(days: 1),
                  ),
                );

                tempTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(postData.value.time),
                );

                if (tempDate != null && tempTime != null) {
                  tempDate = tempDate.copyWith(
                      hour: tempTime.hour, minute: tempTime.minute);
                  postData.value = postData.value.copyWith(time: tempDate);
                }
              },
              leading: Icon(Icons.access_time),
              title: Text(
                  "${postData.value.time.month}月${postData.value.time.day}日 ${postData.value.time.hour.toString().padLeft(2, "0")}:${postData.value.time.minute.toString().padLeft(2, "0")}"),
              trailing: Icon(Icons.arrow_forward_rounded),
            ),
          ),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton(
                onPressed: () {
                  postData.value =
                      postData.value.copyWith(imagePaths: imagePaths.value);
                  postData.value = postData.value
                      .copyWith(comment: textController.value.text);
                  postData.value = postData.value
                      .copyWith(type: segmentedButtonSelected.value.first);

                  ref.read(postProvider.notifier)
                    ..set(postData.value)
                    ..submit();

                  Navigator.of(context).pop();
                  // この後にAlertDialogでも表示する
                },
                child: Text("投稿する")),
          ),
        ],
      ),
    );
  }
}
