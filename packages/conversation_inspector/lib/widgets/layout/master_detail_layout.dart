import 'package:flutter/material.dart';

/// A master-detail layout with a resizable split between left and right panels.
class MasterDetailLayout extends StatefulWidget {
  final Widget master;
  final Widget detail;
  final double initialMasterWidth;
  final double minMasterWidth;
  final double maxMasterWidth;

  const MasterDetailLayout({
    super.key,
    required this.master,
    required this.detail,
    this.initialMasterWidth = 350,
    this.minMasterWidth = 200,
    this.maxMasterWidth = 500,
  });

  @override
  State<MasterDetailLayout> createState() => _MasterDetailLayoutState();
}

class _MasterDetailLayoutState extends State<MasterDetailLayout> {
  late double _masterWidth;

  @override
  void initState() {
    super.initState();
    _masterWidth = widget.initialMasterWidth;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: _masterWidth,
          child: widget.master,
        ),
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _masterWidth = (_masterWidth + details.delta.dx).clamp(
                  widget.minMasterWidth,
                  widget.maxMasterWidth,
                );
              });
            },
            child: Container(
              width: 8,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 1,
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
          ),
        ),
        Expanded(child: widget.detail),
      ],
    );
  }
}
