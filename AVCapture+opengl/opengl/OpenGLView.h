//
//  OpenGLView.h
//  HelloOpenGL
//
//  Created by guoyf on 2018/3/1.
//  Copyright © 2018年 guoyf. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>

@interface OpenGLView : UIView{
    
    CAEAGLLayer* _eaglLayer;        //用于承载绘制OpenGl图像的layer
    EAGLContext* _context;          //管理所有通过OpenGL进行draw的信息
    GLuint _colorRenderBuffer;      //渲染缓冲区
    
    GLuint _positionSlot;           //位置跟踪
    GLuint _colorSlot;              //颜色跟踪
    GLuint _texCoordSlot;           //纹理
    GLuint _projectionUniform;      //投影均衡
    GLuint _modelViewUniform;       //变形均衡（放大缩小旋转）
    float _currentRotation;         //标记当前旋转角度
    
    GLuint _depthRenderBuffer;      //深度渲染缓冲区
    GLuint _floorTexture;           //纹理标记
    GLuint _textureUniform;         //纹理均衡
}

-(void)updateWithX:(CGFloat)x Y:(CGFloat)y Z:(CGFloat)z W:(CGFloat)w;

-(void)updateLocationWithX:(CGFloat)x Y:(CGFloat)y Z:(CGFloat)z;

@end
