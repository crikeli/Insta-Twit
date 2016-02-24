//
//  RWTableViewCell.h
//  More RAC
//
//  Created by Kelin Christi on 02/23/2016.
//  Copyright (c) 2016 Kelz. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RWTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *twitterAvatarView;
@property (weak, nonatomic) IBOutlet UILabel *twitterStatusText;
@property (weak, nonatomic) IBOutlet UILabel *twitterUsernameText;
@end
