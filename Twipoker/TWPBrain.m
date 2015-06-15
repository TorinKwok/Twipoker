/*=============================================================================┐
|             _  _  _       _                                                  |  
|            (_)(_)(_)     | |                            _                    |██
|             _  _  _ _____| | ____ ___  ____  _____    _| |_ ___              |██
|            | || || | ___ | |/ ___) _ \|    \| ___ |  (_   _) _ \             |██
|            | || || | ____| ( (__| |_| | | | | ____|    | || |_| |            |██
|             \_____/|_____)\_)____)___/|_|_|_|_____)     \__)___/             |██
|                                                                              |██
|                 _______    _             _                 _                 |██
|                (_______)  (_)           | |               | |                |██
|                    _ _ _ _ _ ____   ___ | |  _ _____  ____| |                |██
|                   | | | | | |  _ \ / _ \| |_/ ) ___ |/ ___)_|                |██
|                   | | | | | | |_| | |_| |  _ (| ____| |    _                 |██
|                   |_|\___/|_|  __/ \___/|_| \_)_____)_|   |_|                |██
|                             |_|                                              |██
|                                                                              |██
|                         Copyright (c) 2015 Tong Guo                          |██
|                                                                              |██
|                             ALL RIGHTS RESERVED.                             |██
|                                                                              |██
└==============================================================================┘██
  ████████████████████████████████████████████████████████████████████████████████
  ██████████████████████████████████████████████████████████████████████████████*/

#import "TWPBrain.h"
#import "TWPLoginUsersManager.h"
#import "TWPTweetUpdateObject.h"
#import "TWPRetweetUpdateObject.h"

#import "_TWPMonitoringUserID.h"

// TWPBrain class
@implementation TWPBrain

@synthesize currentTwitterUser;
@synthesize friendsList = _friendsList;

#pragma mark Initializations
+ ( instancetype ) wiseBrain
    {
    return [ [ [ self class ] alloc ] init ];
    }

TWPBrain static __strong* sWiseBrain;
- ( instancetype ) init
    {
    if ( !sWiseBrain )
        {
        if ( self = [ super init ] )
            {
            // Home Timeline
            // Single-user stream, containing roughly all of the data corresponding with
            // the current authenticating user’s view of Twitter.
            self->_authingUserTimelineStream = [ [ TWPLoginUsersManager sharedManager ] currentLoginUser ].twitterAPI;
            self->_authingUserTimelineStream.delegate = self;

            [ self->_authingUserTimelineStream fetchUserStreamIncludeMessagesFromFollowedAccounts: @NO
                                                                                   includeReplies: @NO
                                                                                  keywordsToTrack: nil
                                                                            locationBoundingBoxes: nil ];
            // Global Timeline
            // Streams of the public data flowing through Twitter.
            self->_publicTimelineFilterStream = [ [ TWPLoginUsersManager sharedManager ] currentLoginUser ].twitterAPI;
            self->_publicTimelineFilterStream.delegate = self;
            [ self->_publicTimelineFilterStream fetchStatusesFilterKeyword: @"@NSTongG" users: nil locationBoundingBoxes: nil ];

            self->_friendsList = [ NSMutableSet set ];
            self->_monitoringUserIDs = [ NSMutableSet set ];

            self->_uniqueTweetsQueue = [ NSMutableArray array ];

            [ self->_authingUserTimelineStream getUsersShowForUserID: [ [ TWPLoginUsersManager sharedManager ] currentLoginUser ].userID
                                                        orScreenName: nil
                                                     includeEntities: @YES
                                                        successBlock:
                ^( NSDictionary* _User )
                    {
                    self.currentTwitterUser = [ OTCTwitterUser userWithJSON: _User ];
                    } errorBlock: ^( NSError* _Error ) { NSLog( @"%@", _Error ); } ];

            sWiseBrain = self;
            }
        }

    return sWiseBrain;
    }

#pragma mark Operations
- ( void ) showDetailsOfTweet: ( NSString* )_TweetIDString
                 successBlock: ( void (^)( OTCTweet* _Tweet ) )_SuccessBlock
                   errorBlock: ( void (^)( NSError* _Error ) )_ErrorBlock
    {
    [ [ [ TWPLoginUsersManager sharedManager ] currentLoginUser ].twitterAPI
        getStatusesShowID: _TweetIDString
                 trimUser: @NO
         includeMyRetweet: @YES
          includeEntities: @YES
             successBlock:
        ^( NSDictionary* _StatusJSON )
            {
            if ( _SuccessBlock ) _SuccessBlock( [ OTCTweet tweetWithJSON: _StatusJSON ] );
            } errorBlock: ^( NSError* _Error )
                            {
                            if ( _ErrorBlock ) _ErrorBlock( _Error );
                            } ];
    }

- ( void ) pushTweetUpdate: ( TWPTweetUpdateObject* )_TweetUpdateObj
              successBlock: ( void (^)( OTCTweet* _PushedTweet ) )_SuccessBlock
                errorBlock: ( void (^)( NSError* _Error ) )_ErrorBlock
    {
    [ [ [ TWPLoginUsersManager sharedManager ] currentLoginUser ].twitterAPI
        postStatusUpdate: _TweetUpdateObj.tweetText
       inReplyToStatusID: _TweetUpdateObj.replyToTweet.tweetIDString
                mediaIDs: _TweetUpdateObj.mediaURLs
                latitude: nil
               longitude: nil
                 placeID: nil
      displayCoordinates: @NO
                trimUser: @NO
            successBlock:
        ^( NSDictionary* _StatusJSON )
            {
            if ( _SuccessBlock ) _SuccessBlock( [ OTCTweet tweetWithJSON: _StatusJSON ] );
            } errorBlock: ^( NSError* _Error)
                            {
                            if ( _ErrorBlock ) _ErrorBlock( _Error );
                            } ];
    }

- ( void ) favTweet: ( OTCTweet* )_Tweet
       successBlock: ( void (^)( OTCTweet* _FavedTweet ) )_SuccessBlock
         errorBlock: ( void (^)( NSError* _Error ) )_ErrorBlock
    {
    [ [ [ TWPLoginUsersManager sharedManager ] currentLoginUser ].twitterAPI
        postFavoriteCreateWithStatusID: _Tweet.tweetIDString
                       includeEntities: @YES
                          successBlock:
        ^( NSDictionary* _FavedStatusJSON )
            {
            if ( _SuccessBlock ) _SuccessBlock( [ OTCTweet tweetWithJSON: _FavedStatusJSON ] );
            } errorBlock: ^( NSError* _Error )
                            {
                            if ( _ErrorBlock ) _ErrorBlock( _Error );
                            } ];

    }

- ( void ) unfavTweet: ( OTCTweet* )_Tweet
         successBlock: ( void (^)( OTCTweet* _FavedTweet ) )_SuccessBlock
           errorBlock: ( void (^)( NSError* _Error ) )_ErrorBlock
    {
    [ [ [ TWPLoginUsersManager sharedManager ] currentLoginUser ].twitterAPI
        postFavoriteDestroyWithStatusID: _Tweet.tweetIDString
                        includeEntities: @YES
                           successBlock:
        ^( NSDictionary* _UnfavedStatusJSON )
            {
            if ( _SuccessBlock ) _SuccessBlock( [ OTCTweet tweetWithJSON: _UnfavedStatusJSON ] );
            } errorBlock: ^( NSError* _Error )
                            {
                            if ( _ErrorBlock ) _ErrorBlock( _Error );
                            } ];
    }

- ( void ) postRetweetUpdate: ( TWPRetweetUpdateObject* )_RetweetUpdateObj
                successBlock: ( void (^)( OTCTweet* _Retweet ) )_SuccessBlock
                  errorBlock: ( void (^)( NSError* _Error ) )_ErrorBlock
    {
    TWPTweetUpdateObject* quoteTweetUpdate = [ TWPTweetUpdateObject tweetUpdate ];

    TWPRetweetType retweetType = _RetweetUpdateObj.retweetType;
    switch ( retweetType )
        {
        case TWPRetweetTypeOfficialQuote:
            {
            quoteTweetUpdate.tweetText = [ NSString stringWithFormat: @"%@ %@", _RetweetUpdateObj.comment, _RetweetUpdateObj.tweetToBeRetweeted.URLOnWeb ];
            [ self pushTweetUpdate: quoteTweetUpdate successBlock: _SuccessBlock errorBlock: _ErrorBlock ];
            } break;

        case TWPRetweetTypeNormal:
            {
            [ [ [ TWPLoginUsersManager sharedManager ] currentLoginUser ].twitterAPI
                postStatusRetweetWithID: _RetweetUpdateObj.tweetToBeRetweeted.tweetIDString
                               trimUser: @NO
                           successBlock:
                ^( NSDictionary* _UnfavedStatusJSON )
                    {
                    if ( _SuccessBlock ) _SuccessBlock( [ OTCTweet tweetWithJSON: _UnfavedStatusJSON ] );
                    } errorBlock: ^( NSError* _Error )
                                    {
                                    if ( _ErrorBlock ) _ErrorBlock( _Error );
                                    } ];
            } break;

        default:;
        }
    }

- ( void ) destroyTweet: ( OTCTweet* )_Tweet
           successBlock: ( void (^)( OTCTweet* _DestroyedTweet ) )_SuccessBlock
             errorBlock: ( void (^)( NSError* _Error ) )_ErrorBlock
    {
    [ [ [ TWPLoginUsersManager sharedManager ] currentLoginUser ].twitterAPI
        postStatusesDestroy: _Tweet.tweetIDString
                   trimUser: @NO
               successBlock:
        ^( NSDictionary* _DestroyedTweetJSON )
            {
            if ( _SuccessBlock ) _SuccessBlock( [ OTCTweet tweetWithJSON: _DestroyedTweetJSON ] );
            } errorBlock: ^( NSError* _Error )
                            {
                            if ( _ErrorBlock ) _ErrorBlock( _Error );
                            } ];
    }

#pragma mark Registration of Limbs
- ( void ) registerLimb: ( NSObject <TWPLimb>* )_NewLimb
             forUserIDs: ( NSArray* )_UserIDs
            brainSignal: ( TWPBrainSignalTypeMask )_BrainSignals
    {
    NSParameterAssert( ( _NewLimb ) );

    if ( _UserIDs )
        {
        for ( NSString* _UserID in _UserIDs )
            {
            _TWPMonitoringUserID* monitoringUserID = [ _TWPMonitoringUserID IDWithUserID: _UserID signalMask: _BrainSignals limb: _NewLimb ];
            [ self->_monitoringUserIDs addObject: monitoringUserID ];
            }
        }
    else
        [ self->_monitoringUserIDs addObject: [ _TWPMonitoringUserID IDWithUserID: nil signalMask: _BrainSignals limb: _NewLimb ] ];
    }

- ( void ) removeLimb: ( NSObject <TWPLimb>* )_Limb
           forUserIDs: ( NSArray* )_UserIDs
          brainSignal: ( TWPBrainSignalTypeMask )_BrainSignals
    {
    if ( _UserIDs )
        {
        for ( NSString* _UserID in _UserIDs )
            {
            _TWPMonitoringUserID* monitoringUserID = [ _TWPMonitoringUserID IDWithUserID: _UserID signalMask: _BrainSignals limb: _Limb ];
            [ self->_monitoringUserIDs removeObject: monitoringUserID ];
            }
        }
    else
        [ self->_monitoringUserIDs removeObject: [ _TWPMonitoringUserID IDWithUserID: nil signalMask: _BrainSignals limb: _Limb ] ];
    }

#pragma mark Conforms to <OTCSTTwitterStreamingAPIDelegate> protocol
- ( void )      twitterAPI: ( STTwitterAPI* )_TwitterAPI
    didReceiveFriendsLists: ( NSArray* )_Friends
    {
    [ self->_friendsList addObjectsFromArray: _Friends ];
    }

// When parsing Tweets,
// keep in mind that Retweets are streamed as a status with another status nested inside it.
- ( void ) twitterAPI: ( STTwitterAPI* )_TwitterAPI didReceiveTweet: ( OTCTweet* )_ReceivedTweet
    {
    if ( ![ self->_uniqueTweetsQueue containsObject: _ReceivedTweet ] )
        {
        [ self->_uniqueTweetsQueue addObject: _ReceivedTweet ];

        NSNumber* currentLoginUserID = @( [ [ TWPLoginUsersManager sharedManager ] currentLoginUser ].userID.longLongValue );
        NSNumber* authorID = [ NSNumber numberWithLongLong: _ReceivedTweet.author.ID ];

        for ( _TWPMonitoringUserID* _MntID in self->_monitoringUserIDs )
            {
            if ( _MntID.userID.longLongValue == authorID.longLongValue /* Specified user */
                    || !_MntID.userID /* Current authenticating user */ )
                {
                if ( _MntID.signalMask & TWPBrainSignalTypeNewTweetMask )
                    if ( _ReceivedTweet.type == OTCTweetTypeNormalTweet )
                        if ( ( [ self->_friendsList containsObject: authorID ] || authorID == currentLoginUserID )
                                && [ _MntID.limb respondsToSelector: @selector( brain:didReceiveTweet: ) ] )
                            [ _MntID.limb brain: self didReceiveTweet: _ReceivedTweet ];

                if ( _MntID.signalMask & TWPBrainSignalTypeRetweetMask )
                    if ( _ReceivedTweet.type == OTCTweetTypeRetweet )
                        if ( [ _MntID.limb respondsToSelector: @selector( brain:didReceiveRetweet: ) ] )
                            [ _MntID.limb brain: self didReceiveRetweet: _ReceivedTweet ];

                if( _MntID.signalMask & TWPBrainSignalTypeMentionedMeMask )
                    {
                    NSArray* userMentions = _ReceivedTweet.userMentions;
                    if ( userMentions.count > 0 )
                        {
                        for ( OTCUserMention* _UserMention in userMentions )
                            {
                            if ( [ _UserMention.userIDString isEqualToString:
                                [ [ TWPLoginUsersManager sharedManager ] currentLoginUser ].userID ] )
                                {
                                if ( [ _MntID.limb respondsToSelector: @selector( brain:didReceiveMention: ) ] )
                                    [ _MntID.limb brain: self didReceiveMention: _ReceivedTweet ];

                                break;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

- ( void )             twitterAPI: ( STTwitterAPI* )_TwitterAPI
    streamingEventHasBeenDetected: ( OTCStreamingEvent* )_DetectedEvent
    {
    OTCTwitterUser* sourceUser = _DetectedEvent.sourceUser;
    OTCTwitterUser* targetUser = _DetectedEvent.targetUser;

    NSString* sourceUserID = sourceUser.IDString;
    NSString* targetUserID = targetUser.IDString;

    SEL friendsListOperation = nil;
    switch ( _DetectedEvent.eventType)
        {
        case OTCStreamingEventTypeFollow: friendsListOperation = @selector( addObject: ); break;
        case OTCStreamingEventTypeUnfollow: friendsListOperation = @selector( removeObject: ); break;

        default:;
        }

    if ( friendsListOperation && targetUserID )
        [ self->_friendsList performSelectorOnMainThread: friendsListOperation withObject: targetUserID waitUntilDone: YES ];

    for ( _TWPMonitoringUserID* _MntID in self->_monitoringUserIDs )
        {
        if ( [ _MntID.userID isEqualToString: sourceUserID ] /* Specified user */
                || !_MntID.userID /* Current authenticating user */ )
            {
            if ( _MntID.signalMask & TWPBrainSignalTypeTimelineEventMask
                    && [ _MntID.limb respondsToSelector: @selector( brain:didReceiveEvent: ) ] )
                [ _MntID.limb brain: self didReceiveEvent: _DetectedEvent ];
            }
        }
    }

- ( void )   twitterAPI: ( STTwitterAPI* )_TwitterAPI
    tweetHasBeenDeleted: ( NSString* )_DeletedTweetID
                 byUser: ( NSString* )_UserID
                     on: ( NSDate* )_DeletionDate
    {
    for ( OTCTweet* tweet in self->_uniqueTweetsQueue )
        {
        if ( [ tweet.tweetIDString isEqualToString: _DeletedTweetID ] )
            {
            [ self->_uniqueTweetsQueue removeObject: tweet ];
            break;
            }
        }

    for ( _TWPMonitoringUserID* _MntID in self->_monitoringUserIDs )
        {
        if ( [ _MntID.userID isEqualToString: _UserID ] /* Specified user */
                || !_MntID.userID /* Current authenticating user */ )
            {
            if ( _MntID.signalMask & TWPBrainSignalTypeTweetDeletionMask
                    && [ _MntID.limb respondsToSelector: @selector( brain:didReceiveTweetDeletion:byUser:on: ) ] )
                [ _MntID.limb brain: self didReceiveTweetDeletion: _DeletedTweetID byUser: _UserID on: _DeletionDate ];
            }
        }
    }

- ( void ) twitterAPI: ( STTwitterAPI* )_TwitterAPI
     sentOrReceivedDM: ( OTCDirectMessage* )_DirectMessage
    {
    NSNumber* senderID = [ NSNumber numberWithLongLong: _DirectMessage.sender.ID ];

    for ( _TWPMonitoringUserID* _MntID in self->_monitoringUserIDs )
        {
        if ( _MntID.userID.longLongValue == senderID.longLongValue /* Specified user */
                || !_MntID.userID /* Current authenticating user */ )
            {
            if ( _MntID.signalMask & TWPBrainSignalTypeDirectMessagesMask )
                {
                if ( [ _MntID.limb respondsToSelector: @selector( brain:didReceiveDirectMessage: ) ] )
                    [ _MntID.limb brain: self didReceiveDirectMessage: _DirectMessage ];
                }
            }
        }
    }

@end // TWPBrain class

/*=============================================================================┐
|                                                                              |
|                                        `-://++/:-`    ..                     |
|                    //.                :+++++++++++///+-                      |
|                    .++/-`            /++++++++++++++/:::`                    |
|                    `+++++/-`        -++++++++++++++++:.                      |
|                     -+++++++//:-.`` -+++++++++++++++/                        |
|                      ``./+++++++++++++++++++++++++++/                        |
|                   `++/++++++++++++++++++++++++++++++-                        |
|                    -++++++++++++++++++++++++++++++++`                        |
|                     `:+++++++++++++++++++++++++++++-                         |
|                      `.:/+++++++++++++++++++++++++-                          |
|                         :++++++++++++++++++++++++-                           |
|                           `.:++++++++++++++++++/.                            |
|                              ..-:++++++++++++/-                              |
|                             `../+++++++++++/.                                |
|                       `.:/+++++++++++++/:-`                                  |
|                          `--://+//::-.`                                      |
|                                                                              |
└=============================================================================*/