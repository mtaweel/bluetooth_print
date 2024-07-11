#import "BluetoothPrintPlugin.h"
#import "ConnecterManager.h"
#import "EscCommand.h"
#import "TscCommand.h"

@interface BluetoothPrintPlugin ()
@property(nonatomic, retain) NSObject<FlutterPluginRegistrar> *registrar;
@property(nonatomic, retain) FlutterMethodChannel *channel;
@property(nonatomic, retain) BluetoothPrintStreamHandler *stateStreamHandler;
@property(nonatomic, assign) int stateID;
@property(nonatomic) NSMutableDictionary *scannedPeripherals;
@end

@implementation BluetoothPrintPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:NAMESPACE @"/methods"
            binaryMessenger:[registrar messenger]];
  FlutterEventChannel* stateChannel = [FlutterEventChannel eventChannelWithName:NAMESPACE @"/state" binaryMessenger:[registrar messenger]];
  BluetoothPrintPlugin* instance = [[BluetoothPrintPlugin alloc] init];

  instance.channel = channel;
  instance.scannedPeripherals = [NSMutableDictionary new];
    
  // STATE
  BluetoothPrintStreamHandler* stateStreamHandler = [[BluetoothPrintStreamHandler alloc] init];
  [stateChannel setStreamHandler:stateStreamHandler];
  instance.stateStreamHandler = stateStreamHandler;

  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSLog(@"call method -> %@", call.method);
    
  if ([@"state" isEqualToString:call.method]) {
    result([NSNumber numberWithInt:self.stateID]);
  } else if([@"isAvailable" isEqualToString:call.method]) {
    
    result(@(YES));
  } else if([@"isConnected" isEqualToString:call.method]) {
    
    bool isConnected = self.stateID == 1;

    result(@(isConnected));
  } else if([@"isOn" isEqualToString:call.method]) {
    result(@(YES));
  }else if([@"startScan" isEqualToString:call.method]) {
      NSLog(@"getDevices method -> %@", call.method);
      [self.scannedPeripherals removeAllObjects];
      
      if (Manager.bleConnecter == nil) {
          [Manager didUpdateState:^(NSInteger state) {
              switch (state) {
                  case CBCentralManagerStateUnsupported:
                      NSLog(@"The platform/hardware doesn't support Bluetooth Low Energy.");
                      break;
                  case CBCentralManagerStateUnauthorized:
                      NSLog(@"The app is not authorized to use Bluetooth Low Energy.");
                      break;
                  case CBCentralManagerStatePoweredOff:
                      NSLog(@"Bluetooth is currently powered off.");
                      break;
                  case CBCentralManagerStatePoweredOn:
                      [self startScan];
                      NSLog(@"Bluetooth power on");
                      break;
                  case CBCentralManagerStateUnknown:
                  default:
                      break;
              }
          }];
      } else {
          [self startScan];
      }
      
    result(nil);
  } else if([@"stopScan" isEqualToString:call.method]) {
    [Manager stopScan];
    result(nil);
  } else if([@"connect" isEqualToString:call.method]) {
    NSDictionary *device = [call arguments];
    @try {
      NSLog(@"connect device begin -> %@", [device objectForKey:@"name"]);
      CBPeripheral *peripheral = [_scannedPeripherals objectForKey:[device objectForKey:@"address"]];
        
      self.state = ^(ConnectState state) {
        [self updateConnectState:state];
      };
      [Manager connectPeripheral:peripheral options:nil timeout:2 connectBlack: self.state];
      
      result(nil);
    } @catch(FlutterError *e) {
      result(e);
    }
  } else if([@"disconnect" isEqualToString:call.method]) {
    @try {
      [Manager close];
      result(nil);
    } @catch(FlutterError *e) {
      result(e);
    }
  } else if([@"print" isEqualToString:call.method]) {
     @try {
       
       result(nil);
     } @catch(FlutterError *e) {
       result(e);
     }
  } else if([@"printReceipt" isEqualToString:call.method]) {
       @try {
         NSDictionary *args = [call arguments];
         [Manager write:[self mapToEscCommand:args]];
         result(nil);
       } @catch(FlutterError *e) {
         result(e);
       }
  } else if([@"printLabel" isEqualToString:call.method]) {
     @try {
       NSDictionary *args = [call arguments];
       [Manager write:[self mapToTscCommand:args]];
       result(nil);
     } @catch(FlutterError *e) {
       result(e);
     }
  }else if([@"printTest" isEqualToString:call.method]) {
     @try {
       
       result(nil);
     } @catch(FlutterError *e) {
       result(e);
     }
  }
}

-(NSData *)mapToTscCommand:(NSDictionary *) args {
    NSDictionary *config = [args objectForKey:@"config"];
    NSMutableArray *list = [args objectForKey:@"data"];
    
    NSNumber *width = ![config objectForKey:@"width"]?@"48" : [config objectForKey:@"width"];
    NSNumber *height = ![config objectForKey:@"height"]?@"80" : [config objectForKey:@"height"];
    NSNumber *gap = ![config objectForKey:@"gap"]?@"2" : [config objectForKey:@"gap"];
    
    TscCommand *command = [[TscCommand alloc]init];
    // 设置标签尺寸宽高，按照实际尺寸设置 单位mm
    [command addSize:[width intValue] :[height intValue]];
    // 设置标签间隙，按照实际尺寸设置，如果为无间隙纸则设置为0 单位mm
    [command addGapWithM:[gap intValue] withN:0];
    // 设置原点坐标
    [command addReference:0 :0];
    // 撕纸模式开启
    [command addTear:@"ON"];
    // 开启带Response的打印，用于连续打印
    [command addQueryPrinterStatus:ON];
    // 清除打印缓冲区
    [command addCls];
    
    for(NSDictionary *m in list){
        
        NSString *type = [m objectForKey:@"type"];
        NSString *content = [m objectForKey:@"content"];
        NSNumber *x = ![m objectForKey:@"x"]?@0 : [m objectForKey:@"x"];
        NSNumber *y = ![m objectForKey:@"y"]?@0 : [m objectForKey:@"y"];
        
        if([@"text" isEqualToString:type]){
            [command addTextwithX:[x intValue] withY:[y intValue] withFont:@"TSS24.BF2" withRotation:0 withXscal:1 withYscal:1 withText:content];
        }else if([@"barcode" isEqualToString:type]){
            [command add1DBarcode:[x intValue] :[y intValue] :@"CODE128" :100 :1 :0 :2 :2 :content];
        }else if([@"qrcode" isEqualToString:type]){
            [command addQRCode:[x intValue] :[y intValue] :@"L" :5 :@"A" :0 :content];
        }else if([@"image" isEqualToString:type]){
            NSData *decodeData = [[NSData alloc] initWithBase64EncodedString:content options:0];
            UIImage *image = [UIImage imageWithData:decodeData];
            [command addBitmapwithX:[x intValue] withY:[y intValue] withMode:0 withWidth:300 withImage:image];
        }
       
    }
    
    [command addPrint:1 :1];
    return [command getCommand];
}

-(NSData *)mapToEscCommand:(NSDictionary *) args {
    NSDictionary *config = [args objectForKey:@"config"];
    NSMutableArray *list = [args objectForKey:@"data"];
    
    EscCommand *command = [[EscCommand alloc]init];
    [command addInitializePrinter];
    [command addPrintAndFeedLines:3];

    for(NSDictionary *m in list){
        
        NSString *type = [m objectForKey:@"type"];
        NSString *content = [m objectForKey:@"content"];
        NSNumber *align = ![m objectForKey:@"align"]?@0 : [m objectForKey:@"align"];
        NSNumber *size = ![m objectForKey:@"size"]?@4 : [m objectForKey:@"size"];
        NSNumber *weight = ![m objectForKey:@"weight"]?@0 : [m objectForKey:@"weight"];
        NSNumber *width = ![m objectForKey:@"width"]?@0 : [m objectForKey:@"width"];
        NSNumber *height = ![m objectForKey:@"height"]?@0 : [m objectForKey:@"height"];
        NSNumber *underline = ![m objectForKey:@"underline"]?@0 : [m objectForKey:@"underline"];
        NSNumber *linefeed = ![m objectForKey:@"linefeed"]?@0 : [m objectForKey:@"linefeed"];
        
        //内容居左（默认居左）
        [command addSetJustification:[align intValue]];
        
        if([@"text" isEqualToString:type]){
            
            Byte mode = PrintModeEnumDefault;
            if ([weight intValue] == 1) mode = mode | PrintModeEnumBold;
            if ([underline intValue] == 1) mode = mode | PrintModeEnumUnderline;
            [command addPrintMode: mode];

            Byte size = CharacterSizeEnumDefault;
            if ([height intValue] == 1) size = size | CharacterSizeEnumDoubleHeight;
            if ([width intValue] == 1) size = size | CharacterSizeEnumDoubleWidth;
            [command addSetCharcterSize: size];
            
            [command addText:content];
            [command addPrintMode: PrintModeEnumDefault];
            [command addSetCharcterSize: CharacterSizeEnumDefault];

        }else if([@"barcode" isEqualToString:type]){
            [command addSetBarcodeWidth:2];
            [command addSetBarcodeHeight:60];
            [command addSetBarcodeHRPosition:2];
            [command addCODE128:'B' : content];
        }else if([@"qrcode" isEqualToString:type]){
           //  This code snippet has been copied from https://stackoverflow.com/q/34608340/1993514
           int store_len = (int )content.length + 3;
           int pl = (store_len % 256);
           [command addQRCodeSizewithpL:0  withpH:0    withcn:49 withyfn:67 withn:[size intValue]];
           [command addQRCodeLevelwithpL:0 withpH:0    withcn:49 withyfn:69 withn:[size intValue]];
           [command addQRCodeSavewithpL:pl withpH:0    withcn:49 withyfn:80 withm:48 withData:[content dataUsingEncoding:NSASCIIStringEncoding]];
           [command addQRCodePrintwithpL:3 withpH:pl+3 withcn:49 withyfn:81 withm:48];
        }else if([@"image" isEqualToString:type]){
            NSData *decodeData = [[NSData alloc] initWithBase64EncodedString:content options:0];
            UIImage *image = [UIImage imageWithData:decodeData];
            // [command addOriginrastBitImage:image width:576];
            [command addNSDataToCommand:[self createEscPosCommandForImage: image width:(NSInteger)width]];
        }
        
        if([linefeed isEqualToNumber:@1]){
            [command addPrintAndLineFeed];
        }
       
    }
    
    [command addPrintAndFeedLines:4];
    return [command getCommand];
}

-(NSData *) convertImageToBitmapData:(UIImage *)image {
    CGImageRef imageRef = [image CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);

    // Create a grayscale color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    uint8_t *bitmapData = (uint8_t *)calloc(height * width, sizeof(uint8_t));

    CGContextRef context = CGBitmapContextCreate(bitmapData, width, height, 8, width, colorSpace, kCGImageAlphaNone);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);

    NSData *data = [NSData dataWithBytes:bitmapData length:height * width];

    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(bitmapData);

    return data;
}

-(NSData *) bitmapToEscPosData:(NSData *) bitmapData width:(NSUInteger) width  height:(NSUInteger) height {
    NSMutableData *escPosData = [NSMutableData data];

    NSUInteger bytesPerRow = (width + 7) / 8;
    uint8_t commandHeader[] = {0x1D, 0x76, 0x30, 0x00};
    [escPosData appendBytes:commandHeader length:sizeof(commandHeader)];

    // Append width and height
    uint8_t widthL = bytesPerRow & 0xFF;
    uint8_t widthH = (bytesPerRow >> 8) & 0xFF;
    uint8_t heightL = height & 0xFF;
    uint8_t heightH = (height >> 8) & 0xFF;

    [escPosData appendBytes:&widthL length:1];
    [escPosData appendBytes:&widthH length:1];
    [escPosData appendBytes:&heightL length:1];
    [escPosData appendBytes:&heightH length:1];

    uint8_t rowData[bytesPerRow];
    for (NSUInteger y = 0; y < height; y++) {
        memset(rowData, 0, bytesPerRow);
        for (NSUInteger x = 0; x < width; x++) {
            NSUInteger byteIndex = y * width + x;
            if (((uint8_t *)bitmapData.bytes)[byteIndex] < 128) {
                NSUInteger bitIndex = x % 8;
                rowData[x / 8] |= (0x80 >> bitIndex);
            }
        }
        [escPosData appendBytes:rowData length:bytesPerRow];
    }

    return escPosData;
}

UIImage *resizeImage(UIImage *image, CGSize newSize) {
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

UIImage *convertToGrayscale(UIImage *image) {
    CGRect imageRect = CGRectMake(0, 0, image.size.width, image.size.height);
    int width = imageRect.size.width;
    int height = imageRect.size.height;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(nil, width, height, 8, 0, colorSpace, kCGImageAlphaNone);
    CGContextDrawImage(context, imageRect, [image CGImage]);

    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    UIImage *newImage = [UIImage imageWithCGImage:imageRef];

    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(imageRef);

    return newImage;
}

UIImage *applyDithering(UIImage *image) {
    // Simple dithering algorithm (Floyd-Steinberg or other) can be implemented here.
    CGImageRef imageRef = [image CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);

    // Create a grayscale color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    uint8_t *bitmapData = (uint8_t *)calloc(height * width, sizeof(uint8_t));

    CGContextRef context = CGBitmapContextCreate(bitmapData, width, height, 8, width, colorSpace, kCGImageAlphaNone);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);

    // Apply Floyd-Steinberg dithering
    for (NSUInteger y = 0; y < height; y++) {
        for (NSUInteger x = 0; x < width; x++) {
            NSUInteger index = y * width + x;
            uint8_t oldPixel = bitmapData[index];
            uint8_t newPixel = oldPixel > 127 ? 255 : 0;
            bitmapData[index] = newPixel;
            int error = oldPixel - newPixel;

            if (x + 1 < width) {
                bitmapData[index + 1] = MIN(MAX(bitmapData[index + 1] + error * 7 / 16, 0), 255);
            }
            if (x > 0 && y + 1 < height) {
                bitmapData[index + width - 1] = MIN(MAX(bitmapData[index + width - 1] + error * 3 / 16, 0), 255);
            }
            if (y + 1 < height) {
                bitmapData[index + width] = MIN(MAX(bitmapData[index + width] + error * 5 / 16, 0), 255);
            }
            if (x + 1 < width && y + 1 < height) {
                bitmapData[index + width + 1] = MIN(MAX(bitmapData[index + width + 1] + error * 1 / 16, 0), 255);
            }
        }
    }

    // Create a new CGImage from the modified bitmap data
    CGImageRef newImageRef = CGBitmapContextCreateImage(context);
    UIImage *ditheredImage = [UIImage imageWithCGImage:newImageRef];

    // Clean up
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(bitmapData);
    CGImageRelease(newImageRef);

    return ditheredImage;
}

- (NSData *)createEscPosCommandForImage:(UIImage *) image width:(NSInteger) twidth{
    // Resize image to desired width, maintain aspect ratio
    CGFloat targetWidth = twidth; // Width in pixels for the printer
    CGFloat aspectRatio = image.size.height / image.size.width;
    CGSize newSize = CGSizeMake(targetWidth, targetWidth * aspectRatio);
    UIImage *resizedImage = resizeImage(image, newSize);

    // Convert to grayscale
    UIImage *grayscaleImage = convertToGrayscale(resizedImage);

    // Apply dithering (optional)
    UIImage *ditheredImage = applyDithering(grayscaleImage);

        // Convert to bitmap data
    NSData *bitmapData = [self convertImageToBitmapData:ditheredImage];
    if (!bitmapData) {
        return nil;
    }

    NSUInteger width = CGImageGetWidth(ditheredImage.CGImage);
    NSUInteger height = CGImageGetHeight(ditheredImage.CGImage);
    NSData *escPosData = [self bitmapToEscPosData:bitmapData width:width height:height];

    return escPosData;
}

-(void)startScan {
    [Manager scanForPeripheralsWithServices:nil options:nil discover:^(CBPeripheral * _Nullable peripheral, NSDictionary<NSString *,id> * _Nullable advertisementData, NSNumber * _Nullable RSSI) {
        if (peripheral.name != nil) {
            
            NSLog(@"find device -> %@", peripheral.name);
            [self.scannedPeripherals setObject:peripheral forKey:[[peripheral identifier] UUIDString]];
            
            NSDictionary *device = [NSDictionary dictionaryWithObjectsAndKeys:peripheral.identifier.UUIDString,@"address",peripheral.name,@"name",nil,@"type",nil];
            [_channel invokeMethod:@"ScanResult" arguments:device];
        }
    }];
    
}

-(void)updateConnectState:(ConnectState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSNumber *ret = @0;
        switch (state) {
            case CONNECT_STATE_CONNECTING:
                NSLog(@"status -> %@", @"连接状态：连接中....");
                ret = @0;
                self.stateID = 0;
                break;
            case CONNECT_STATE_CONNECTED:
                NSLog(@"status -> %@", @"连接状态：连接成功");
                ret = @1;
                self.stateID = 1;
                break;
            case CONNECT_STATE_FAILT:
                NSLog(@"status -> %@", @"连接状态：连接失败");
                ret = @0;
                break;
            case CONNECT_STATE_DISCONNECT:
                NSLog(@"status -> %@", @"连接状态：断开连接");
                ret = @0;
                self.stateID = -1;
                break;
            default:
                NSLog(@"status -> %@", @"连接状态：连接超时");
                ret = @0;
                self.stateID = -1;
                break;
        }
        
         NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:ret,@"id",nil];
        if(_stateStreamHandler.sink != nil) {
          self.stateStreamHandler.sink([dict objectForKey:@"id"]);
        }
    });
}

@end

@implementation BluetoothPrintStreamHandler

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
  self.sink = eventSink;
  return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
  self.sink = nil;
  return nil;
}

@end
