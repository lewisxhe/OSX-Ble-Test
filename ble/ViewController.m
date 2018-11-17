//
//  ViewController.m
//  ble
//
//  Created by lewis on 2018/7/1.
//  Copyright © 2018年 lewis. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#include <unistd.h>
#define BLE_NAME @"C12-Demo" // // @"ZeSport 9"@"ZeSport 2" //
#define TARAGE_DIR  @"/Users/lewishe/Downloads/ZS2_V0.7.0_180706_PACKET/V000500"
#define TARAGE_PATH @"/Users/lewishe/Downloads/ZS2_V0.7.0_180706_PACKET/V000500/"
#define CRC_PATH @"/Users/lewishe/Downloads/ZS2_V0.7.0_180706_PACKET/V000500/crc.data"
#define CONFIG_PATH @"/Users/lewishe/Downloads/ZS2_V0.7.0_180706_PACKET/V000500/config.cfg"

#define MY_ADD_FALG
typedef enum
{
    RECV_FLAG_SUCCESS,
    RECV_FLAG_FAIL,
    RECV_FLAG_PARSER_SUCCESS,
    RECV_FLAG_PARSER_FAIL,
#ifdef MY_ADD_FALG
    RECV_FLAG_HAVE_FILE,
#endif
    RECV_FLAG_INVALID,
}RECV_STATE;

RECV_STATE recv_state;
NSThread * thread;

@interface ViewController()<CBCentralManagerDelegate,CBPeripheralDelegate>
@property(nonatomic,strong)CBCentralManager *mgr;
@property(nonatomic,strong)CBPeripheral *per;
@property(nonatomic,strong)CBCharacteristic * fba2;
@end

@implementation ViewController



- (void)viewDidLoad {
    [super viewDidLoad];
    self.mgr = [[CBCentralManager alloc]initWithDelegate:self queue:nil];
}



#pragma mark - 中心代理
//状态
-(void)centralManagerDidUpdateState:(CBCentralManager *)central{
    
    switch (central.state) {
        case CBManagerStateUnknown:
            NSLog(@"》》》CBManagerStateUnknown");
            break;
        case CBManagerStateResetting:
            NSLog(@"》》》CBManagerStateResetting");
            break;
        case CBManagerStateUnsupported:
            NSLog(@"》》》CBManagerStateUnsupported");
            break;
        case CBManagerStateUnauthorized:
            NSLog(@"》》》CBManagerStateUnauthorized");
            break;
        case CBManagerStatePoweredOn:
            NSLog(@"》》》CBManagerState打开...");
            [self.mgr scanForPeripheralsWithServices:nil options:nil];
            break;
        case CBManagerStatePoweredOff:
            NSLog(@"》》》CBManagerState关闭...");
            break;
        default:
            NSLog(@"》》》CBManagerState other...");
            break;
    }

}
//连接代理，扫描外设
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    NSLog(@"peripheral %@",peripheral.name);
    [self.per discoverServices:nil];
}

//发现服务
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI{
    
        
    if ([peripheral.name isEqualToString:BLE_NAME]){
        NSLog(@"peripheral = %@",peripheral);
        self.per = peripheral;
        self.per.delegate = self;
        [self.mgr connectPeripheral:peripheral options:nil];
        [self.mgr stopScan];
    }
}

//断开链接
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    NSLog(@"已经断开链接");
}

//扫描服务
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    
    NSLog(@"peripheral services = %@ count:%lu",peripheral.services,peripheral.services.count);
    
    for(CBService * ser in peripheral.services)
    {
        //过滤服务
        if( [ser.UUID.UUIDString isEqualToString:@"BBA0"]){
            NSLog(@"UUID : %@",ser.UUID.UUIDString);
            //扫描所有特征
            [self.per discoverCharacteristics:nil forService:ser];
        }
    }
}

//扫描特征
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{

    NSLog(@"-------------------------------------------");
    NSUInteger max = [self.per maximumWriteValueLengthForType:(CBCharacteristicWriteWithResponse)];
    NSLog(@"CBCharacteristicWriteWithResponse : %lu",max);
    max = [self.per maximumWriteValueLengthForType:(CBCharacteristicWriteWithoutResponse)];
    NSLog(@"CBCharacteristicWriteWithoutResponse : %lu",max);
    NSLog(@"-------------------------------------------");

    
    NSLog(@"打开之前Characteristic %@ count:%lu",service.characteristics,service.characteristics.count);
    for(CBCharacteristic * c in service.characteristics){
        NSLog(@"Characteristic : %@",c);
        if([c.UUID.UUIDString isEqualToString:@"FB06"]){
            NSLog(@"@打开notify...");
            [self notifyCharacteristic:self.per characteristic: c];
        }
        
        if([c.UUID.UUIDString isEqualToString:@"FBA2"]){
            [self.per discoverDescriptorsForCharacteristic:c];
            self.fba2 = c;
//            [self.per readValueForCharacteristic:c];
        }
    }
}


//扫描描述符
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    NSLog(@"description %@",characteristic.description);
//    for(CBDescriptor *dp in characteristic.descriptors){
//        [self.per readValueForDescriptor:dp];
//写特征
//        self.per writeValue:<#(nonnull NSData *)#> forCharacteristic:<#(nonnull CBCharacteristic *)#> type:<#(CBCharacteristicWriteType)#>;
//写描述符
//        self.per writeValue:<#(nonnull NSData *)#> forDescriptor:<#(nonnull CBDescriptor *)#>;
//设置notify
//        self.per setNotifyValue:<#(BOOL)#> forCharacteristic:<#(nonnull CBCharacteristic *)#>;
//    }
}



-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    NSArray *a = [[NSArray alloc]initWithObjects:characteristic.value, nil];
    Byte* f = (Byte*) [[a objectAtIndex:0] bytes];
    if (f[0] == 0x04){
        switch (f[1]) {
            case 0x00:
                NSLog(@"recv success");
                recv_state = RECV_FLAG_SUCCESS;
                break;
            case 0x01:
                recv_state = RECV_FLAG_FAIL;
                NSLog(@"recv fail");
                break;
            case 0x02:
                recv_state = RECV_FLAG_PARSER_SUCCESS;
                NSLog(@"resource pares success");
                break;
            case 0x03:
                recv_state = RECV_FLAG_PARSER_FAIL;
                NSLog(@"resource pares fail");
                break;
#ifdef MY_ADD_FALG
            case 0x04:
                recv_state = RECV_FLAG_HAVE_FILE;
                NSLog(@"resources already exist");
                break;
#endif
            default:
                break;
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error{
    NSLog(@"recv descriptor ");
}

// 设置通知，自定义方法
- (void)notifyCharacteristic:(CBPeripheral *)peripheral characteristic:(CBCharacteristic *)characteristic{
    // 设置通知，数据通知会进入：didUpdateValueForCharacteristic 方法
    [peripheral setNotifyValue:YES forCharacteristic:characteristic];
}

// 取消通知，自定义方法
- (void)cancelNotifyCharacteristic:(CBPeripheral *)peripheral characteristic:(CBCharacteristic *)characteristic{
    [peripheral setNotifyValue:NO forCharacteristic:characteristic];
}

- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error{
    
    NSLog(@"RSSI: %@",RSSI);
}

- (Byte*)getIntegerToBytes:(NSInteger)value{
    static Byte byteData[4] = {};
    byteData[0] =(Byte)((value & 0xFF000000)>>24);
    byteData[1] =(Byte)((value & 0x00FF0000)>>16);
    byteData[2] =(Byte)((value & 0x0000FF00)>>8);
    byteData[3] =(Byte)((value & 0x000000FF));
    return byteData;
}


- (void)sendResource{
    
    BOOL isFrist = true;
//    NSArray *fileList = [[NSFileManager  defaultManager]  directoryContentsAtPath:TARAGE_DIR];
    NSArray *fileList =[[NSFileManager defaultManager]contentsOfDirectoryAtPath:TARAGE_DIR error:nil];

    NSInteger i = 0;
    for(NSString * name  in fileList)
    {
        NSLog(@"Send --->>>  %@",name);

        if([name isEqualToString:@"config.cfg"] || [name isEqualToString:@"crc.data"]){
            continue;
        }
        NSString* path  = [TARAGE_PATH stringByAppendingString:name];
RELOAD:
        NSLog(@"path : %@",path);
        recv_state = RECV_FLAG_INVALID;
        //原始数据
        NSData* sourceData = [NSData dataWithContentsOfFile:path];
        Byte * sendBytes = (Byte*)[sourceData bytes];

        //文件名称
        NSData* nameData = [name dataUsingEncoding:NSASCIIStringEncoding];
        //文件名称长度
        NSUInteger nameLen = [name length];
        //数据总长度
        NSUInteger dataLen = [sourceData length];
        
        //要发送的总长度 标识(1 Byte) + 数据长度 + 文件名称长度 + 1 Byte(文件名长度)
//        NSInteger count = dataLen + nameLen ;
        
        NSUInteger packSize = 99;//[self.per maximumWriteValueLengthForType:CBCharacteristicWriteWithResponse] - 4;
        NSLog(@"max mtu : %lu",packSize);
        
        Byte sendArray[packSize];
        
        NSUInteger offset = 0;
        
        
        while(true)
        {
            if(isFrist)
            {
                isFrist = false;
                //标识 1 Byte
                sendArray[0] = 0x02;
                //文件名称长度 1Byte
                sendArray[1] = nameLen;
                //文件名 ...
                memcpy(&sendArray[2], (Byte*)[nameData bytes], nameLen);
                //文件大小 4 Bytes
                memcpy(&sendArray[nameLen + 2], &dataLen, sizeof(uint32_t));
                
                NSUInteger c = packSize - nameLen - 6;
                
                NSLog(@"filesize : %lu" ,dataLen);
                
                memcpy(&sendArray[nameLen + 6], sendBytes, c);
                //剩余长度
                offset =dataLen - (dataLen - c);
                
                NSData * send = [[NSData alloc]initWithBytes:sendArray length:sizeof(sendArray)];
                [self.per writeValue:send forCharacteristic:self.fba2 type:CBCharacteristicWriteWithResponse];
         
//    2018-07-04 16:04:21.522386+0800 ble[19051:2028873] -------------------------------------------
//    2018-07-04 16:04:21.522448+0800 ble[19051:2028873] CBCharacteristicWriteWithResponse : 512
//    2018-07-04 16:04:21.522477+0800 ble[19051:2028873] CBCharacteristicWriteWithoutResponse : 101
//    2018-07-04 16:04:21.522499+0800 ble[19051:2028873] -------------------------------------------
                
            }
            else
            {
#ifdef MY_ADD_FALG
                if(recv_state == RECV_FLAG_HAVE_FILE)
                {
                    break;
                }
#endif
                sendArray[0] = 0x02;
                NSUInteger sendlen = (dataLen - offset) > (packSize-1) ? packSize-1 : dataLen - offset;
                memcpy(&sendArray[1],&sendBytes[offset],sendlen);
                NSLog(@"[%ld] 发送 : %lu offset : %lu",i,sendlen,offset);
                offset += sendlen;
                NSData * sendData = [[NSData alloc]initWithBytes:sendArray length:sendlen+1];
                [self.per writeValue:sendData forCharacteristic:self.fba2 type:CBCharacteristicWriteWithResponse];
                if(sendlen != packSize-1)
                {
                    NSLog(@"break.............");
                    break;
                }
            }
        }
        while(1)
        {
//            if(i == fileList.count-3)
            if(i == fileList.count-1)
            {
                NSLog(@"Success....\n");
                return;
            }
#ifdef MY_ADD_FALG
            if(recv_state == RECV_FLAG_HAVE_FILE)
            {
                break;
            }
#endif
            if(recv_state == RECV_FLAG_FAIL)
            {
                NSLog(@"------------->>> recv Fail ...");
                [NSThread sleepForTimeInterval:5];
                isFrist = true;
                goto RELOAD;
            }
            else if(recv_state == RECV_FLAG_SUCCESS || recv_state == RECV_FLAG_PARSER_SUCCESS)
            {
                NSLog(@">>>Recv : %d",recv_state);
                recv_state = RECV_FLAG_INVALID;
                break;
            }
//            NSLog(@"Wait ...");
//            NSLog(@"Rssi : %@",[self.per readRSSI]);
            [self.per readRSSI];
            [NSThread sleepForTimeInterval:2];
        }
        isFrist = true;
        i++;
//        [NSThread sleepForTimeInterval:2];
    }
}



- (void)sendConfigFile{
    /*
     配置文件
     1.标识 <1 Bytes>  0x01
     2.CRC <2 Bytes>
     3.长度 <4 Bytes>
     */
    NSFileManager *manage = [NSFileManager defaultManager];
    NSData *data = [manage contentsAtPath:CRC_PATH];
    NSString *fileContents = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    uint16_t crc = [fileContents integerValue];
    NSLog(@"crc : %u ",crc);

    
    data = [NSData dataWithContentsOfFile:CONFIG_PATH];
    NSLog(@"config len : %lu",[data length]);
    Byte *testByte = (Byte *)[data bytes];
//    NSInteger len = [data length];
    NSInteger len = [data length];
    
    Byte sendArray[90];
    
    

    BOOL isFrist = true;
    NSInteger offset = 0;
    //分包次数
    uint8_t count = len + 7;
    uint8_t packetCount = count % 90 == 0 ? len / 90 : len /90 +1;
    NSLog(@"packetCount : %i",packetCount);
    
//    for (uint8_t i=0;i<packetCount;i++){
    while(1){
        if(isFrist){
            isFrist = false;
            //97 bytes
            sendArray[0] = 0x01;
            sendArray[1] = (crc & 0xFF);
            sendArray[2] = (crc >> 8) & 0xFF;
            sendArray[6] =(Byte)((len & 0xFF000000)>>24);
            sendArray[5] =(Byte)((len & 0x00FF0000)>>16);
            sendArray[4] =(Byte)((len & 0x0000FF00)>>8);
            sendArray[3] =(Byte)((len & 0x000000FF));
            memcpy(&sendArray[7],testByte, 90-7);
            offset += 90-7;
            len -= 90-7;
            NSData * sendData = [[NSData alloc]initWithBytes:sendArray length:sizeof(sendArray)];
            [self.per writeValue:sendData forCharacteristic:self.fba2 type:CBCharacteristicWriteWithResponse];
        }
        else
        {
            
            sendArray[0] = 0x01;
            //发送的长度
            // 总长度 - 偏移长度  > 89 ? 89 : 剩余长度
            NSInteger sendlen = (([data length]  - offset) > 89) ? 89 : [data length] - offset;
            NSLog(@"发送 : %lu offset : %lu",sendlen,offset);
            memcpy(&sendArray[1],&testByte[offset],sendlen);
            offset += sendlen;
            len -= sendlen;
            NSData * sendData = [[NSData alloc]initWithBytes:sendArray length:sendlen+1];
            [self.per writeValue:sendData forCharacteristic:self.fba2 type:CBCharacteristicWriteWithResponse];
            if(sendlen != 89){
                NSLog(@"break config ...");
                break;
            }
        }
    }
}

- (IBAction)Connet:(NSButton *)sender {
    
}
- (IBAction)Scan:(NSButton *)sender {
    
}

- (IBAction)Send:(NSButton *)sender {
    NSLog(@"send btn..");
    [self sendConfigFile];
}
- (IBAction)check:(NSButton *)sender {
}
- (IBAction)resource:(NSButton *)sender {
    NSLog(@"sendResource btn..");
     thread = [[NSThread alloc]initWithTarget:self selector:@selector(sendResource) object:nil];
    [thread start];
}


@end
