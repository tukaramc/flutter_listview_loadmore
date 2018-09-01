import 'dart:async';

import 'package:flutter/material.dart';

/// return true is refresh success
///
/// return false or null is fail
typedef Future<bool> FutureCallBack();

class LoadMore extends StatefulWidget {
  final Widget child;

  /// return true is refresh success
  ///
  /// return false or null is fail
  final FutureCallBack onLoadMore;
  final bool isFinish;
  final LoadMoreDelegate delegate;
  final LoadMoreTextBuilder textBuilder;

  const LoadMore({
    Key key,
    @required this.child,
    @required this.onLoadMore,
    this.textBuilder = DefaultLoadMoreTextBuilder.chinese,
    this.isFinish = false,
    this.delegate = const DefaultLoadMoreDelegate(),
  }) : super(key: key);

  @override
  _LoadMoreState createState() => _LoadMoreState();
}

class _LoadMoreState extends State<LoadMore> {
  Widget get child => widget.child;

  LoadMoreDelegate get loadMoreDelegate => widget.delegate;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onLoadMore == null) {
      return child;
    }
    if (child is ListView) {
      return _buildListView(child);
    }
    return child;
  }

  /// if call the method, then the future is not null
  /// so, return a listview and  item count + 1
  Widget _buildListView(ListView listView) {
    var delegate = listView.childrenDelegate;
    if (delegate is SliverChildBuilderDelegate) {
      SliverChildBuilderDelegate delegate = listView.childrenDelegate;
      var viewCount = delegate.estimatedChildCount + 1;
      IndexedWidgetBuilder builder = (context, index) {
        if (index == viewCount - 1) {
          return _buildLoadMoreView();
        }
        return delegate.builder(context, index);
      };

      return ListView.builder(
        itemBuilder: builder,
        addAutomaticKeepAlives: delegate.addAutomaticKeepAlives,
        addRepaintBoundaries: delegate.addRepaintBoundaries,
        itemCount: viewCount,
        cacheExtent: listView.cacheExtent,
        controller: listView.controller,
        itemExtent: listView.itemExtent,
        key: listView.key,
        padding: listView.padding,
        physics: listView.physics,
        primary: listView.primary,
        reverse: listView.reverse,
        scrollDirection: listView.scrollDirection,
        shrinkWrap: listView.shrinkWrap,
      );
    } else if (delegate is SliverChildListDelegate) {
      SliverChildListDelegate delegate = listView.childrenDelegate;
      delegate.children.add(_buildLoadMoreView());
      return ListView(
        children: delegate.children,
        addAutomaticKeepAlives: delegate.addAutomaticKeepAlives,
        addRepaintBoundaries: delegate.addRepaintBoundaries,
        cacheExtent: listView.cacheExtent,
        controller: listView.controller,
        itemExtent: listView.itemExtent,
        key: listView.key,
        padding: listView.padding,
        physics: listView.physics,
        primary: listView.primary,
        reverse: listView.reverse,
        scrollDirection: listView.scrollDirection,
        shrinkWrap: listView.shrinkWrap,
      );
    }
    return listView;
  }

  LoadMoreStatus status = LoadMoreStatus.idle;

  Widget _buildLoadMoreView() {
    if (widget.isFinish == true) {
      this.status = LoadMoreStatus.nomore;
    } else {
      if (this.status == LoadMoreStatus.nomore) {
        this.status = LoadMoreStatus.idle;
      }
    }
    return NotificationListener<_RetryNotify>(
      child: NotificationListener<_BuildNotify>(
        child: DefaultLoadMoreView(
          status: status,
          delegate: loadMoreDelegate,
          textBuilder: widget.textBuilder,
        ),
        onNotification: _onLoadMoreBuild,
      ),
      onNotification: _onRetry,
    );
  }

  bool _onLoadMoreBuild(_BuildNotify notification) {
    //判断状态，触发对应的操作
    if (status == LoadMoreStatus.loading) {
      return false;
    }
    if (status == LoadMoreStatus.nomore) {
      return false;
    }
    if (status == LoadMoreStatus.fail) {
      return false;
    }
    if (status == LoadMoreStatus.idle) {
      // 切换状态为加载中，并且触发回调
      loadMore();
    }
    return false;
  }

  void _updateStatus(LoadMoreStatus status) {
    setState(() => this.status = status);
  }

  bool _onRetry(_RetryNotify notification) {
    loadMore();
    return false;
  }

  void loadMore() {
    _updateStatus(LoadMoreStatus.loading);
    widget.onLoadMore().then((v) {
      if (v == true) {
        // 成功，切换状态为空闲
        _updateStatus(LoadMoreStatus.idle);
      } else {
        // 失败，切换状态为失败
        _updateStatus(LoadMoreStatus.fail);
      }
    });
  }
}

enum LoadMoreStatus {
  /// 空闲中，表示当前等待加载
  ///
  /// wait for loading
  idle,

  /// 刷新中，不应该继续加载，等待future返回
  ///
  /// the view is loading
  loading,

  /// 刷新失败，刷新失败，这时需要点击才能刷新
  ///
  /// loading fail, need tap view to loading
  fail,

  /// 没有更多，没有更多数据了，这个状态不触发任何条件
  ///
  /// not have more data
  nomore,
}

class DefaultLoadMoreView extends StatefulWidget {
  final LoadMoreStatus status;
  final LoadMoreDelegate delegate;
  final LoadMoreTextBuilder textBuilder;
  const DefaultLoadMoreView({
    Key key,
    this.status = LoadMoreStatus.idle,
    @required this.delegate,
    @required this.textBuilder,
  }) : super(key: key);

  @override
  DefaultLoadMoreViewState createState() => DefaultLoadMoreViewState();
}

const _defaultLoadMoreHeight = 80.0;
const _loadmoreIndicatorSize = 33.0;
const _loadMoreDelay = 100;

class DefaultLoadMoreViewState extends State<DefaultLoadMoreView> {
  LoadMoreDelegate get delegate => widget.delegate;

  @override
  Widget build(BuildContext context) {
    notify();
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (widget.status == LoadMoreStatus.fail ||
            widget.status == LoadMoreStatus.idle) {
          _RetryNotify().dispatch(context);
        }
      },
      child: Container(
        height: delegate.widgetHeight(widget.status),
        alignment: Alignment.center,
        child: delegate.buildChild(
          widget.status,
          builder: widget.textBuilder,
        ),
      ),
    );
  }

  void notify() async {
    await Future.delayed(delegate.loadMoreDelay());
    if (widget.status == LoadMoreStatus.idle) {
      _BuildNotify().dispatch(context);
    }
  }
}

class _BuildNotify extends Notification {}

class _RetryNotify extends Notification {}

abstract class LoadMoreDelegate {
  const LoadMoreDelegate();

  double widgetHeight(LoadMoreStatus status) => _defaultLoadMoreHeight;

  Duration loadMoreDelay() => Duration(milliseconds: _loadMoreDelay);

  Widget buildChild(LoadMoreStatus status,
      {LoadMoreTextBuilder builder = DefaultLoadMoreTextBuilder.chinese});
}

class DefaultLoadMoreDelegate extends LoadMoreDelegate {
  const DefaultLoadMoreDelegate();

  @override
  Widget buildChild(LoadMoreStatus status,
      {LoadMoreTextBuilder builder = DefaultLoadMoreTextBuilder.chinese}) {
    String text = builder(status);
    if (status == LoadMoreStatus.fail) {
      return Container(
        child: Text(text),
      );
    }
    if (status == LoadMoreStatus.idle) {
      return Text(text);
    }
    if (status == LoadMoreStatus.loading) {
      return Container(
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: _loadmoreIndicatorSize,
              height: _loadmoreIndicatorSize,
              child: CircularProgressIndicator(
                backgroundColor: Colors.blue,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(text),
            ),
          ],
        ),
      );
    }
    if (status == LoadMoreStatus.nomore) {
      return Text(text);
    }

    return Text(text);
  }
}

typedef String LoadMoreTextBuilder(LoadMoreStatus status);

String _buildChineseText(LoadMoreStatus status) {
  String text;
  switch (status) {
    case LoadMoreStatus.fail:
      text = "加载失败，请点击重试";
      break;
    case LoadMoreStatus.idle:
      text = "等待加载更多";
      break;
    case LoadMoreStatus.loading:
      text = "加载中，请稍候...";
      break;
    case LoadMoreStatus.nomore:
      text = "到底了，别扯了";
      break;
    default:
      text = "";
  }
  return text;
}

String _buildEnglishText(LoadMoreStatus status) {
  String text;
  switch (status) {
    case LoadMoreStatus.fail:
      text = "load fail, tap to retry";
      break;
    case LoadMoreStatus.idle:
      text = "wait for loading";
      break;
    case LoadMoreStatus.loading:
      text = "loading, wait for moment ...";
      break;
    case LoadMoreStatus.nomore:
      text = "no more data";
      break;
    default:
      text = "";
  }
  return text;
}

class DefaultLoadMoreTextBuilder {
  static const LoadMoreTextBuilder chinese = _buildChineseText;

  static const LoadMoreTextBuilder english = _buildEnglishText;
}
