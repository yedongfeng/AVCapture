# AVCapture
AVFoundation实现自定义相机拍照功能，实现了闪光灯、自拍、设置对焦点等基本功能以及涂鸦功能（OpenGL）、马赛克、添加水印logo后期编辑。

涂鸦功能使用了OpenGL，一些地图也会使用OpenGL绘制，会有冲突；应关闭地图OpenGL相关功能。

如高德地图：

    _mapView.openGLESDisabled = YES;//关闭地图的OpenGL
    
    _mapView.openGLESDisabled = NO; //打开地图的OpenGL


