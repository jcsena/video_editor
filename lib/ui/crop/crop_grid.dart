import 'package:flutter/material.dart';
import 'package:video_editor/domain/entities/transform_data.dart';
import 'package:video_editor/ui/crop/crop_grid_painter.dart';
import 'package:video_editor/domain/bloc/controller.dart';
import 'package:video_editor/ui/video_viewer.dart';
import 'package:video_editor/ui/transform.dart';

enum _CropBoundaries {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  inside,
  topCenter,
  centerRight,
  centerLeft,
  bottomCenter,
  none
}

class CropGridViewer extends StatefulWidget {
  ///It is the viewer that allows you to crop the video
  CropGridViewer({
    Key? key,
    required this.controller,
    this.showGrid = true,
  }) : super(key: key);

  /// If it is true, it shows the grid and allows cropping the video, if it is false
  /// does not show the grid and cannot be cropped
  final bool showGrid;

  ///Essential argument for the functioning of the Widget
  final VideoEditorController controller;

  @override
  _CropGridViewerState createState() => _CropGridViewerState();
}

class _CropGridViewerState extends State<CropGridViewer> {
  _CropBoundaries _boundary = _CropBoundaries.none;
  ValueNotifier<Rect> _rect = ValueNotifier<Rect>(Rect.zero);
  ValueNotifier<TransformData> _transform = ValueNotifier<TransformData>(
    TransformData(rotation: 0.0, scale: 1.0, translate: Offset.zero),
  );

  Size _layout = Size.zero;
  Offset _margin = Offset.zero;

  double? _preferredCropAspectRatio;
  late VideoEditorController _controller;

  @override
  void initState() {
    _controller = widget.controller;
    _preferredCropAspectRatio = _controller.preferredCropAspectRatio;
    final double lenght = _controller.cropStyle.boundariesLenght;
    _margin = Offset(lenght, lenght) * 2;
    if (!widget.showGrid) _controller.addListener(_scaleRect);
    super.initState();
  }

  @override
  void dispose() {
    if (!widget.showGrid) _controller.removeListener(_scaleRect);
    _transform.dispose();
    _rect.dispose();
    super.dispose();
  }

  void _scaleRect() {
    _rect.value = _calculateCropRect();
    _transform.value = TransformData.fromRect(
      _rect.value,
      _layout,
      _controller,
    );
  }

  void _onPanStart(DragStartDetails details) {
    final Offset pos = details.localPosition;
    final Offset max = _rect.value.bottomRight;
    final Offset min = _rect.value.topLeft;

    final List<Offset> minMargin = [min - _margin, min + _margin];
    final List<Offset> maxMargin = [max - _margin, max + _margin];

    if (pos >= minMargin[0] && pos <= maxMargin[1]) {
      final List<Offset> topCenter = [
        _rect.value.topCenter - _margin,
        _rect.value.topCenter + _margin,
      ];
      final List<Offset> centerLeft = [
        _rect.value.centerLeft - _margin,
        _rect.value.centerLeft + _margin,
      ];
      final List<Offset> bottomCenter = [
        _rect.value.bottomCenter - _margin,
        _rect.value.bottomCenter + _margin
      ];
      final List<Offset> centerRight = [
        _rect.value.centerRight - _margin,
        _rect.value.centerRight + _margin,
      ];

      //CORNERS
      if (pos >= minMargin[0] && pos <= minMargin[1]) {
        _boundary = _CropBoundaries.topLeft;
      } else if (pos >= maxMargin[0] && pos <= maxMargin[1]) {
        _boundary = _CropBoundaries.bottomRight;
      } else if (pos >= Offset(maxMargin[0].dx, minMargin[0].dy) &&
          pos <= Offset(maxMargin[1].dx, minMargin[1].dy)) {
        _boundary = _CropBoundaries.topRight;
      } else if (pos >= Offset(minMargin[0].dx, maxMargin[0].dy) &&
          pos <= Offset(minMargin[1].dx, maxMargin[1].dy)) {
        _boundary = _CropBoundaries.bottomLeft;
        //CENTERS
      } else if (_controller.preferredCropAspectRatio == null) {
        if (pos >= topCenter[0] && pos <= topCenter[1]) {
          _boundary = _CropBoundaries.topCenter;
        } else if (pos >= bottomCenter[0] && pos <= bottomCenter[1]) {
          _boundary = _CropBoundaries.bottomCenter;
        } else if (pos >= centerLeft[0] && pos <= centerLeft[1]) {
          _boundary = _CropBoundaries.centerLeft;
        } else if (pos >= centerRight[0] && pos <= centerRight[1]) {
          _boundary = _CropBoundaries.centerRight;
        }
        //OTHERS
        else if (pos >= minMargin[1] && pos <= maxMargin[0]) {
          _boundary = _CropBoundaries.inside;
        } else {
          _boundary = _CropBoundaries.none;
        }
      } else if (pos >= minMargin[1] && pos <= maxMargin[0]) {
        _boundary = _CropBoundaries.inside;
      } else {
        _boundary = _CropBoundaries.none;
      }
    } else {
      _boundary = _CropBoundaries.none;
    }
    _controller.isCropping = true;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_boundary != _CropBoundaries.none) {
      final Offset delta = details.delta;

      switch (_boundary) {
        case _CropBoundaries.inside:
          final Offset pos = _rect.value.topLeft + delta;
          _changeRect(left: pos.dx, top: pos.dy);
          break;
        //CORNERS
        case _CropBoundaries.topLeft:
          final Offset pos = _rect.value.topLeft + delta;
          _changeRect(
            top: pos.dy,
            left: pos.dx,
            width: _rect.value.width - delta.dx,
            height: _rect.value.height - delta.dy,
          );
          break;
        case _CropBoundaries.topRight:
          _changeRect(
            top: _rect.value.topRight.dy + delta.dy,
            width: _rect.value.width + delta.dx,
            height: _rect.value.height - delta.dy,
          );
          break;
        case _CropBoundaries.bottomRight:
          _changeRect(
            width: _rect.value.width + delta.dx,
            height: _rect.value.height + delta.dy,
          );
          break;
        case _CropBoundaries.bottomLeft:
          _changeRect(
            left: _rect.value.bottomLeft.dx + delta.dx,
            width: _rect.value.width - delta.dx,
            height: _rect.value.height + delta.dy,
          );
          break;
        //CENTERS
        case _CropBoundaries.topCenter:
          _changeRect(
            top: _rect.value.top + delta.dy,
            height: _rect.value.height - delta.dy,
          );
          break;
        case _CropBoundaries.bottomCenter:
          _changeRect(height: _rect.value.height + delta.dy);
          break;
        case _CropBoundaries.centerLeft:
          _changeRect(
            left: _rect.value.left + delta.dx,
            width: _rect.value.width - delta.dx,
          );
          break;
        case _CropBoundaries.centerRight:
          _changeRect(width: _rect.value.width + delta.dx);
          break;
        case _CropBoundaries.none:
          break;
      }
    }
  }

  void _onPanEnd(_) {
    if (_boundary != _CropBoundaries.none) {
      final Rect rect = _rect.value;
      _controller.isCropping = false;
      _controller.cacheMinCrop = Offset(
        rect.left / _layout.width,
        rect.top / _layout.height,
      );
      _controller.cacheMaxCrop = Offset(
        rect.right / _layout.width,
        rect.bottom / _layout.height,
      );
    }
  }

  //-----------//
  //RECT CHANGE//
  //-----------//
  void _changeRect({double? left, double? top, double? width, double? height}) {
    top = top ?? _rect.value.top;
    left = left ?? _rect.value.left;
    width = width ?? _rect.value.width;
    height = height ?? _rect.value.height;

    final double right = left + width;
    final double bottom = top + height;

    if (height > _margin.dx && width > _margin.dx) {
      width = right <= _layout.width ? width : _rect.value.width;

      _rect.value = Rect.fromLTWH(
        left >= 0.0
            ? right <= _layout.width
                ? left
                : _rect.value.left
            : 0.0,
        top >= 0.0
            ? bottom <= _layout.height
                ? top
                : _rect.value.top
            : 0.0,
        width,
        bottom <= _layout.height
            ? _preferredCropAspectRatio == null
                ? height
                : width / _preferredCropAspectRatio!
            : _rect.value.height,
      );
    }
  }

  Rect _calculateCropRect() {
    final Offset minCrop = _controller.minCrop;
    final Offset maxCrop = _controller.maxCrop;

    return Rect.fromPoints(
      Offset(minCrop.dx * _layout.width, minCrop.dy * _layout.height),
      Offset(maxCrop.dx * _layout.width, maxCrop.dy * _layout.height),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _transform,
      builder: (_, TransformData transform, __) => CropTransform(
        transform: transform,
        child: VideoViewer(
          controller: _controller,
          child: LayoutBuilder(builder: (_, constraints) {
            Size size = Size(constraints.maxWidth, constraints.maxHeight);
            if (_layout != size) {
              _layout = size;
              _rect.value = _calculateCropRect();
            }

            return AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => ValueListenableBuilder(
                  valueListenable: _rect,
                  builder: (_, Rect value, __) {
                    final left = value.left - _margin.dx;
                    final top = value.top - _margin.dy;
                    return widget.showGrid
                        ? Stack(children: [
                            _paint(),
                            GestureDetector(
                              onPanUpdate: _onPanUpdate,
                              onPanStart: _onPanStart,
                              onPanEnd: _onPanEnd,
                              child: Container(
                                margin: EdgeInsets.only(
                                  left: left < 0.0 ? 0.0 : left,
                                  top: top < 0.0 ? 0.0 : top,
                                ),
                                color: Colors.transparent,
                                width: value.width + _margin.dx * 2,
                                height: value.height + _margin.dy * 2,
                              ),
                            ),
                          ])
                        : _paint();
                  }),
            );
          }),
        ),
      ),
    );
  }

  Widget _paint() {
    return CustomPaint(
      size: Size.infinite,
      painter: CropGridPainter(
        _rect.value,
        style: _controller.cropStyle,
        showGrid: widget.showGrid,
        showCenterRects: _controller.preferredCropAspectRatio == null,
      ),
    );
  }
}