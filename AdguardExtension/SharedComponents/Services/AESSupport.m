/**
    This file is part of Adguard for iOS (https://github.com/AdguardTeam/AdguardForiOS).
    Copyright © 2015 Performix LLC. All rights reserved.

    Adguard for iOS is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Adguard for iOS is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Adguard for iOS.  If not, see <http://www.gnu.org/licenses/>.
*/
#import "AESSupport.h"
#import "ADomain/ADomain.h"
#import "ACommons/ACLang.h"
#import "ACommons/ACSystem.h"
#import "ACommons/ACFiles.h"
#import "AESharedResources.h"
#import "NSData+GZIP.h"
#import "AEService.h"
#import "AESAntibanner.h"
#import "ASDModels/ASDFilterObjects.h"
#import "ABECRequest.h"
#ifdef PRO
#import "APVPNManager.h"
#import "APDnsServerObject.h"
#import "APBlockingSubscriptionsManager.h"
#endif


NSString *AESSupportSubjectPrefixFormat = @"[%@ for iOS] %@";

#define SUPPORT_ADDRESS         @"support@adguard.com"


#define BOOL_TO_STRING(A)       A ? @"Enabled" : @"Disabled"
#define DEFAULT_USER_EMAIL      @"_undefined@mail.com"
#define SEND_LOG_DISABLED       @"SendingLogDisabled"

#define LOG_DELIMETER_FORMAT    @"\r\n-------------------------------------------------------------\r\n"\
@"LOG FILE:%@"\
@"\r\n-------------------------------------------------------------\r\n"

#define REPORT_URL @"https://reports.adguard.com/new_issue.html"

#define REPORT_PARAM_PRODUCT @"product_type"
#define REPORT_PARAM_VERSION @"product_version"
#define REPORT_PARAM_BROWSER @"browser"
#define REPORT_PARAM_URL @"url"
#define REPORT_PARAM_FILTERS @"filters"
#define REPORT_PARAM_SYSTEM_WIDE @"ios.systemwide"
#define REPORT_PARAM_SIMPLIFIED @"ios.simplified"
#define REPORT_PARAM_CUSTOM_DNS @"ios.CustomDNS"
#define REPORT_PARAM_DNS @"ios.DNS"

#define REPORT_PRODUCT @"iOS"
#define REPORT_BROWSER @"Safari"

#define REPORT_DNS_ADGUARD @"Default"
#define REPORT_DNS_ADGUARD_FAMILY @"Family"
#define REPORT_DNS_OTHER @"Other"


/////////////////////////////////////////////////////////////////////
#pragma mark - AESSupport
/////////////////////////////////////////////////////////////////////

@implementation AESSupport

static AESSupport *singletonSupport;

/////////////////////////////////////////////////////////////////////
#pragma mark Initialize
/////////////////////////////////////////////////////////////////////

+ (AESSupport *)singleton{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        singletonSupport = [AESSupport alloc];
        singletonSupport = [singletonSupport init];
    });
    
    return singletonSupport;
    
}

- (id)init{
    
    if (singletonSupport != self) {
        return nil;
    }
    
    self = [super init];
    if (self) {
    }
    
    return self;
}

/////////////////////////////////////////////////////////////////////
#pragma mark Properties and public methods
/////////////////////////////////////////////////////////////////////

- (void)sendMailBugReportWithParentController:(UIViewController *)parent{
    
    if ([MFMailComposeViewController canSendMail]) {
        @autoreleasepool {
            
            MFMailComposeViewController *compose = [MFMailComposeViewController new];
            [compose setMessageBody:@"" isHTML:NO];
            [compose setSubject:[NSString stringWithFormat:AESSupportSubjectPrefixFormat, AE_PRODUCT_NAME, NSLocalizedString(@"Bug Report", @"(AEUIAboutController) Subject field for mail bug report")]];
            NSData *stateData = [[self applicationState] dataUsingEncoding:NSUTF8StringEncoding];
            if (stateData) {
                [compose addAttachmentData:stateData mimeType:@"text/plain" fileName:@"state.txt"];
            }
            NSData *jsonData = [self compressedJson];
            if (jsonData) {
                [compose addAttachmentData:jsonData mimeType:@"application/x-gzip" fileName:@"filter.gz"];
            }
            
            // Flush Logs
            [[ACLLogger singleton] flush];
            //
            
            for (NSURL *item in [self appLogsUrls]) {
                
                NSData *logData = [self applicationLogFromURL:item];
                if (logData) {
                    NSString *fileName = [NSString stringWithFormat:@"%@.gz", [item lastPathComponent]];
                    [compose addAttachmentData:logData mimeType:@"application/x-gzip" fileName:fileName];
                }
            }
            [compose setToRecipients:@[SUPPORT_ADDRESS]];
            compose.mailComposeDelegate = self;
            
            [parent presentViewController:compose animated:YES completion:nil];
        }
        
    }
    else{
        
        [ACSSystemUtils showSimpleAlertForController:parent withTitle:NSLocalizedString(@"Error", @"")
                                             message:NSLocalizedString(@"Can't send bug report because no email is probably set up on your device.", @"(AEUIAboutController) Alert message if user have no e-mail account on device")];
    }
}

- (void)sendSimpleMailWithParentController:(UIViewController *)parent subject:(NSString *)subject body:(NSString *)body{
    
    if ([MFMailComposeViewController canSendMail]) {
        @autoreleasepool {
            
            MFMailComposeViewController *compose = [MFMailComposeViewController new];
            [compose setMessageBody:body isHTML:NO];
            [compose setSubject:subject];

            NSData *stateData = [[self applicationState] dataUsingEncoding:NSUTF8StringEncoding];
            if (stateData) {
                [compose addAttachmentData:stateData mimeType:@"text/plain" fileName:@"state.txt"];
            }
            NSData *jsonData = [self compressedJson];
            if (jsonData) {
                [compose addAttachmentData:jsonData mimeType:@"application/x-gzip" fileName:@"filter.gz"];
            }
            
            [compose setToRecipients:@[SUPPORT_ADDRESS]];
            compose.mailComposeDelegate = self;
            
            [parent presentViewController:compose animated:YES completion:nil];
        }
        
    }
    else{
        
        [ACSSystemUtils showSimpleAlertForController:parent withTitle:NSLocalizedString(@"Error", @"")
                                             message:NSLocalizedString(@"Can't send message to support team because you have no configured email account.", @"(AEUIAboutController) Alert message if user have no e-mail account on device")];
    }

}

- (NSURL *)composeWebReportUrlForSite:(nullable NSURL *)siteUrl {
    
    NSMutableDictionary *params = [NSMutableDictionary new];
    
    if(siteUrl) {
        params[REPORT_PARAM_URL] = siteUrl;
    }
    
    params[REPORT_PARAM_PRODUCT] = REPORT_PRODUCT;
    params[REPORT_PARAM_VERSION] = ADProductInfo.version;
    params[REPORT_PARAM_BROWSER] = REPORT_BROWSER;
    
    NSMutableString *filtersString = [NSMutableString new];
    AESAntibanner* antibaner = [AESAntibanner new];
    NSArray* filterIDs = antibaner.activeFilterIDs;
    
    for (NSNumber *filterId in filterIDs) {
        
        NSString* format = filterId == filterIDs.firstObject ? @"%@" : @".%@";
        [filtersString appendFormat:format, filterId];
    }
    params[REPORT_PARAM_FILTERS] = filtersString.copy;
    
    params[REPORT_PARAM_SIMPLIFIED] =  [[AESharedResources sharedDefaults] boolForKey:AEDefaultsJSONConverterOptimize] ? @"true" : @"false";
    
#ifdef PRO
    
    NSString* dnsServerParam = nil;
    BOOL custom = NO;
    
    APDnsServerObject * dnsServer = [APVPNManager.singleton loadActiveRemoteDnsServer];
    if([dnsServer.uuid isEqualToString:APDnsServerUUIDAdguard]) {
        dnsServerParam = REPORT_DNS_ADGUARD;
    }
    else if ([dnsServer.uuid isEqualToString:APDnsServerUUIDAdguardFamily]) {
        dnsServerParam = REPORT_DNS_ADGUARD_FAMILY;
    }
    else if(dnsServer) {
        dnsServerParam = REPORT_DNS_OTHER;
        custom = YES;
    }
    
    if(dnsServerParam) {
        params[REPORT_PARAM_DNS] = dnsServerParam;
        
        if(custom) {
            params[REPORT_PARAM_CUSTOM_DNS] = dnsServer.serverName;
        }
    }
    
#endif
    
    params[REPORT_PARAM_SYSTEM_WIDE] = @"false";
    
    NSString *paramsString = [ABECRequest createStringFromParameters:params];
    NSString *url = [NSString stringWithFormat:@"%@?%@", REPORT_URL, paramsString];
    
    return [NSURL URLWithString: url];
}


/////////////////////////////////////////////////////////////////////
#pragma mark Mail Compose Delegate Methods
/////////////////////////////////////////////////////////////////////

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error{
    
    [controller dismissViewControllerAnimated:YES completion:nil];
}


/////////////////////////////////////////////////////////////////////////
#pragma mark Private Methods
/////////////////////////////////////////////////////////////////////////

///   Returns some software info to the support message
- (NSString *)applicationState{
    @autoreleasepool {
        
        NSMutableString *sb = [NSMutableString stringWithFormat:@"Application version: %@", [ADProductInfo buildVersion]];
        
        NSURL *supportFolder = [AESharedResources sharedLogsURL];
        if (supportFolder) {
            [sb appendFormat:@"\r\nApplication lifetime: %@", [ACFFileUtils fileCreatedTimeForUrl:supportFolder]];
        }
        UIDevice *dev = [UIDevice currentDevice];
        [sb appendFormat:@"\r\n\r\nDevice: %@", [dev model]];
        [sb appendFormat:@"\r\nPlatform: %@", [dev systemName]];
        [sb appendFormat:@"\r\nOS: %@", [dev systemVersion]];
        [sb appendFormat:@"\r\nID: %@", [[dev identifierForVendor] UUIDString]];
        
        [sb appendFormat:@"\r\n\r\nLocale: %@", [ADLocales lang]];
        [sb appendFormat:@"\r\nRegion: %@", [ADLocales region]];
        
        [sb appendFormat:@"\r\n\r\nOptimized enabled: %@", ([[AESharedResources sharedDefaults] boolForKey:AEDefaultsJSONConverterOptimize] ? @"YES" : @"NO")];
        
        NSNumber *rulesCount = [[AESharedResources sharedDefaults] objectForKey:AEDefaultsJSONConvertedRules];
        NSNumber *totalRulesCount = [[AESharedResources sharedDefaults] objectForKey:AEDefaultsJSONRulesForConvertion];
        [sb appendFormat:@"\r\nRules converted: %@ from: %@.", rulesCount, totalRulesCount];

        [sb appendString:@"\r\n\r\nFilters subscriptions:"];
        NSArray *filters = [[[AEService singleton] antibanner] filters];
        for (ASDFilterMetadata *meta in filters)
            [sb appendFormat:@"\r\nID=%@ Name=\"%@\" Version=%@ Enabled=%@", meta.filterId, meta.name, meta.version, ([meta.enabled boolValue] ? @"YES" : @"NO")];
        
#ifdef PRO
        [sb appendFormat:@"\r\n\r\nPRO:\r\nPro feature %@.\r\nTunnel mode %@\r\nDNS server: %@",
         (APVPNManager.singleton.enabled ? @"ENABLED" : @"DISABLED"),
         //(APVPNManager.singleton.localFiltering ? @"ENABLED" : @"DISABLED"),
         (APVPNManager.singleton.tunnelMode == APVpnManagerTunnelModeFull ? @"FULL" : @"SPLIT"),
         APVPNManager.singleton.activeRemoteDnsServer.serverName];
        
        if (! [APVPNManager.singleton.activeRemoteDnsServer.tag isEqualToString:APDnsServerTagLocal]) {
            
            [sb appendFormat:@"\r\n\%@", APVPNManager.singleton.activeRemoteDnsServer.ipAddressesAsString];
            
            [sb appendFormat:@"\r\nDnsCrypt: %@", APVPNManager.singleton.activeRemoteDnsServer.isDnsCrypt];
        }
        
        NSArray<APBlockingSubscription*> *subscriptions = APBlockingSubscriptionsManager.subscriptions;
        
        if(subscriptions.count) {
            [sb appendFormat:@"\r\n\r\nSystem wide blocking subscriptions: "];
            
            for(APBlockingSubscription* subscription in subscriptions) {
                
                NSString* updateDate = [NSDateFormatter
                                        localizedStringFromDate: subscription.updateDate
                                        dateStyle: NSDateFormatterShortStyle
                                        timeStyle: NSDateFormatterShortStyle];
                [sb appendFormat:@"\r\nname: %@ url: %@ last update: %@", subscription.name, subscription.url, updateDate];
            }
        }
#endif
        return sb;
    }
}


// Get application log data
- (NSData *)applicationLogFromURL:(NSURL *)url{
    
    @autoreleasepool {
        
        DDLogFileManagerDefault *manager = [[DDLogFileManagerDefault alloc] initWithLogsDirectory:[url path]];
        NSArray *logFileInfos = [manager sortedLogFileInfos];
        
        NSMutableData *logData = [NSMutableData dataWithCapacity:ACL_MAX_LOG_FILE_SIZE];
        NSUInteger loadSize = ACL_MAX_LOG_FILE_SIZE;
        NSData *fileData;
        NSStringEncoding enc;
        NSString *fileContent;
        
        for (DDLogFileInfo *info in logFileInfos) {
            
            fileContent = [NSString stringWithFormat:LOG_DELIMETER_FORMAT, info.fileName];
            
            if (fileContent)
                [logData appendData:[fileContent dataUsingEncoding:NSUTF8StringEncoding]];
            
            loadSize = ACL_MAX_LOG_FILE_SIZE - logData.length;
            fileContent = [NSString stringWithContentsOfFile:info.filePath usedEncoding:&enc error:nil];
            if (fileContent) {
                
                fileData = [fileContent dataUsingEncoding:NSUTF8StringEncoding];
                if (fileData.length < loadSize) loadSize = fileData.length;
                
                [logData appendBytes:[fileData bytes] length:loadSize];
                
                if (logData.length >= ACL_MAX_LOG_FILE_SIZE)
                    break;
            }
            
        }
        
        return [logData gzippedData];
    }
}

- (NSArray *)appLogsUrls{
    
    NSURL *logs = [AESharedResources sharedLogsURL];
    return [[NSFileManager defaultManager] contentsOfDirectoryAtURL:logs includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:0 error:NULL];
}

- (NSData *)compressedJson{
    
    
    NSData *json = [[AESharedResources new] blockingContentRules];
    
    return [json gzippedData];
}


@end
