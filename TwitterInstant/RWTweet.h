//
//  RWTweet.h
//  More RAC
//
//  Created by Kelin Christi on 02/23/2016.
//  Copyright (c) 2016 Kelz. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RWTweet : NSObject

@property (strong, nonatomic) NSString *status;

@property (strong, nonatomic) NSString *profileImageUrl;

@property (strong, nonatomic) NSString *username;

+ (instancetype)tweetWithStatus:(NSDictionary *)status;


@end
