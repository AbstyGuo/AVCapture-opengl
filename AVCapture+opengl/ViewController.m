//
//  ViewController.m
//  AVCapture+opengl
//
//  Created by guoyf on 2018/3/13.
//  Copyright © 2018年 guoyf. All rights reserved.
//

#import "ViewController.h"
#import "CaptureViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UIButton * button = [[UIButton alloc] initWithFrame:self.view.bounds];
    [button setTitle:@"开启相机" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(gotoCapture) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
}

-(void)gotoCapture{
    CaptureViewController * cap = [[CaptureViewController alloc] init];
    
    [self presentViewController:cap animated:YES completion:nil];
}

@end
