//
//  RWTweet.m
//  More RAC
//
//  Created by Kelin Christi on 02/23/2016.
//  Copyright (c) 2016 Kelz. All rights reserved.
//

#import "RWTweet.h"

@implementation RWTweet

+ (instancetype)tweetWithStatus:(NSDictionary *)status {
  RWTweet *tweet = [RWTweet new];
  tweet.status = status[@"text"];
  
  NSDictionary *user = status[@"user"];
  tweet.profileImageUrl = user[@"profile_image_url"];
  tweet.username = user[@"screen_name"];
  return tweet;
}

@end
