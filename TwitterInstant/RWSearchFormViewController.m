//
//  RWSearchFormViewController.m
//  TwitterInstant
//
//  Created by Colin Eberhardt on 02/12/2013.
//  Copyright (c) 2013 Colin Eberhardt. All rights reserved.
//

#import "RWSearchFormViewController.h"
#import "RWSearchResultsViewController.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import "ReactiveCocoa/RACEXTScope.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import "RWTweet.h"
#import "NSArray+LinqExtensions.h"

//Enumeration & constant
typedef NS_ENUM(NSInteger, RWTwitterInstanError){
        RWTwitterInstanErrorAccessDenied,
        RWTwitterInstanErrorNoTwitterAccount,
        RWTwitterInstanErrorInvalidResponse
};

static NSString * const RWTwitterInstantDomain = @"TwitterInstant";

@interface RWSearchFormViewController ()

@property (weak, nonatomic) IBOutlet UITextField *searchText;

@property (strong, nonatomic) RWSearchResultsViewController *resultsViewController;


//ACAccount class provides access to various social media accounts through the device.
@property (strong, nonatomic) ACAccountStore *accountStore;
//ACAccountType class represents a specific type of account.
@property (strong, nonatomic) ACAccountType *twitterAccountType;

@end

@implementation RWSearchFormViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.title = @"Twitter Instant";
  
  [self styleTextField:self.searchText];
  
  self.resultsViewController = self.splitViewController.viewControllers[1];
    
    //weakify & strongify is a macro(pre-processor definitions that scans code before it is compiled) that allows to create shadow variables.
    @weakify(self) //captures a weak reference to self.

    //Takes the search text fields signal and transforms it into background color stating validity.
    //Also the beginning of the "pipeline" logic.
  [[self.searchText.rac_textSignal
    map:^id(NSString *text){
        return [self isValidSearchText:text]?
        [UIColor whiteColor] : [UIColor blueColor];
    }]
   //subscribeNext uses self in order to obtain a reference to the text field.
   //if a strong reference exists between self and this signal, it will result in a retain cycle.
   //to avoid a retain cycle, Apple recommends capturing a weak reference to self.
   subscribeNext:^(UIColor *color){
       //Allows to create a strong reference to variables that were previously passed to weakify.
       @strongify(self)
       self.searchText.backgroundColor = color;
   }];
    
    self.accountStore = [[ACAccountStore alloc] init];
    self.twitterAccountType = [self.accountStore
       accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    //Added to make use of the signal
//    [[self requestAccessToTwitterSignal]
//     subscribeNext:^(id x) {
//         NSLog(@"Wilkomen");
//     } error:^(NSError *error) {
//         NSLog(@"An error occurred: %@", error);
//     }];
    
    //The last part of the "pipeline" logic.
    [[[[[[[self requestAccessToTwitterSignal]
      //The then method waits until a completed event is emitted, then it subscribes to the signal returned by its block parameter. That passes control from one signal to another.
      then:^RACSignal *{
          //since the pipeline is already weakified, there is no need to weakify again.
          @strongify(self)
          return self.searchText.rac_textSignal;
      }]
     filter:^BOOL(NSString *text) {
         @strongify(self)
         return [self isValidSearchText:text];
     }]
        //A throttle event will only be sent if another next event is not received within the given time period.
      throttle:0.5]
      flattenMap:^RACStream *(NSString *text){
          @strongify(self)
          return[self signalForSearchWithText:text];
      }]
      //deliverOn allows the computation to execute on the mainthread.
     deliverOn:[RACScheduler mainThreadScheduler]]
     //The subscribe next block obtains an NSArray of tweets and then the linq_select method transforms the array of NSDictionary instances by executing a supplied block on each array into RWTweet instances.
     subscribeNext:^(NSDictionary *jsonSearchResult){
         NSArray *statuses = jsonSearchResult[@"statuses"];
         NSArray *tweets = [statuses linq_select:^id(id tweet){
             return [RWTweet tweetWithStatus:tweet];
         }];
         [self.resultsViewController displayTweets:tweets];
         //The breakpoint illustrates the fact that the computation does not occur on the main thread.
         //In order to populate anything on the UI, updates need to come from the main thread.
         //Non reactive approach would involve NSOperations & NSQueues.
//         NSLog(@"%@", x);
     } error:^(NSError *error){;
         NSLog(@"An Error Occured: %@", error);
     }];
    
}


//Ensures that the search string is longer than 2 characters.
-(BOOL)isValidSearchText:(NSString *)text {
    return text.length > 2;
}

- (void)styleTextField:(UITextField *)textField {
  CALayer *textFieldLayer = textField.layer;
  textFieldLayer.borderColor = [UIColor grayColor].CGColor;
  textFieldLayer.borderWidth = 2.0f;
  textFieldLayer.cornerRadius = 0.0f;
}

- (RACSignal *)requestAccessToTwitterSignal {
    
    // 1 - define an error which is sent if the user refuses access.
    NSError *accessError = [NSError errorWithDomain:RWTwitterInstantDomain
                                               code:RWTwitterInstanErrorAccessDenied
                                           userInfo:nil];
    
    // 2 - create the signal and returns an instance of RACSignal
    @weakify(self)
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        // 3 - request access to twitter via the account store. Here, the user sees the prompt asking to grant access to twitter accounts.
        @strongify(self)
        [self.accountStore
         requestAccessToAccountsWithType:self.twitterAccountType
         options:nil
         completion:^(BOOL granted, NSError *error) {
             // 4 - handle the response depending upon what the user granted.
             if (!granted) {
                 [subscriber sendError:accessError];
             } else {
                 [subscriber sendNext:nil];
                 [subscriber sendCompleted];
             }
         }];
        return nil;
    }];
}

    //The required API method is wrapped and called in a Signal.
- (SLRequest *)requestforTwitterSearchWithText:(NSString *)text {
    NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1.1/search/tweets.json"];
    //The q search parameter is used to search for tweets that contain the given search string.
    NSDictionary *params = @{@"q" : text};
    
    SLRequest *request =  [SLRequest requestForServiceType:SLServiceTypeTwitter
                                             requestMethod:SLRequestMethodGET
                                                       URL:url
                                                parameters:params];
    return request;
}


//A signal is created based on the above request.
- (RACSignal *)signalForSearchWithText:(NSString *)text {
    
    // 1 - define the errors
    NSError *noAccountsError = [NSError errorWithDomain:RWTwitterInstantDomain
                                                   code:RWTwitterInstanErrorNoTwitterAccount
                                               userInfo:nil];
    
    NSError *invalidResponseError = [NSError errorWithDomain:RWTwitterInstantDomain
                                                        code:RWTwitterInstanErrorInvalidResponse
                                                    userInfo:nil];
    
    // 2 - create the signal block
    @weakify(self)
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self);
        
        // 3 - create the request using the method added previously
        SLRequest *request = [self requestforTwitterSearchWithText:text];
        
        // 4 - supply a twitter account and if none are found, an error is transmitted.
        NSArray *twitterAccounts = [self.accountStore
                                    accountsWithAccountType:self.twitterAccountType];
        if (twitterAccounts.count == 0) {
            [subscriber sendError:noAccountsError];
        } else {
            [request setAccount:[twitterAccounts lastObject]];
            
            // 5 - perform the request
            [request performRequestWithHandler: ^(NSData *responseData,
                                                  NSHTTPURLResponse *urlResponse, NSError *error) {
                if (urlResponse.statusCode == 200) {
                    
                    // 6 - on success, parse the response(in json form) and emit as a next event followed by a completed event.
                    NSDictionary *timelineData =
                    [NSJSONSerialization JSONObjectWithData:responseData
                                                    options:NSJSONReadingAllowFragments
                                                      error:nil];
                    [subscriber sendNext:timelineData];
                    [subscriber sendCompleted];
                }
                else {
                    // 7 - send an error on an unsuccesful response.
                    [subscriber sendError:invalidResponseError];
                }
            }];
        }
        
        return nil;
    }];
}



@end
