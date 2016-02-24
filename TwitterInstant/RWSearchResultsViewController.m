//
//  RWSearchResultsViewController.m
//  TwitterInstant
//
//  Created by Colin Eberhardt on 03/12/2013.
//  Copyright (c) 2013 Colin Eberhardt. All rights reserved.
//

#import <ReactiveCocoa/ReactiveCocoa.h>
#import "RWSearchResultsViewController.h"
#import "RWTableViewCell.h"
#import "RWTweet.h"

@interface RWSearchResultsViewController ()

@property (nonatomic, strong) NSArray *tweets;
@end

@implementation RWSearchResultsViewController {

}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.tweets = [NSArray array];
  
}

- (void)displayTweets:(NSArray *)tweets {
  self.tweets = tweets;
  [self.tableView reloadData];
}


#pragma mark - Table view data source


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return self.tweets.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *CellIdentifier = @"Cell";
  RWTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
  
  RWTweet *tweet = self.tweets[indexPath.row];
  cell.twitterStatusText.text = tweet.status;
  cell.twitterUsernameText.text = [NSString stringWithFormat:@"@%@",tweet.username];
    
  //Resets the image cells because data should not be stale.
  cell.twitterAvatarView.image = nil;
  //Creates a signal to fetch image data.
  [[[self signalForLoadingImage:tweet.profileImageUrl]
  //helps the next event to execute on the mainthread so that the subscribeNext block can safely execute.
    deliverOn:[RACScheduler mainThreadScheduler]]
     subscribeNext:^(UIImage *image) {
      cell.twitterAvatarView.image = image;
     }];
  
  return cell;
}

//Executing this code on a different thread(not the main thread)
//The method first obtains a background scheduler.
//A signal is created that downloads image data and creates a UIImage when it has a subscriber.
-(RACSignal *)signalForLoadingImage:(NSString *)imageUrl {
    
    RACScheduler *scheduler = [RACScheduler
                               schedulerWithPriority:RACSchedulerPriorityBackground];
    
    return [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageUrl]];
        UIImage *image = [UIImage imageWithData:data];
        [subscriber sendNext:image];
        [subscriber sendCompleted];
        return nil;
        //Ensures that the signal executes on a given scheduler.
    }] subscribeOn:scheduler];
    
}

@end
