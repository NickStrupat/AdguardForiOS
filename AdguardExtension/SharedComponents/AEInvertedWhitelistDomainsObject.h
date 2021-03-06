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
#import <Foundation/Foundation.h>
#import "ACObject.h"

@class ASDFilterRule;

/////////////////////////////////////////////////////////////////////
#pragma mark - AEInvertedWhitelistDomainsObject


/**
 This class is used to store a list of inverted whitelist domain names and
 content blocker rule from them
 
 Inverted whitelist uses only one rule that includes all domain names from the list
 */
@interface AEInvertedWhitelistDomainsObject : ACObject

/////////////////////////////////////////////////////////////////////
#pragma mark Init and Class methods

/**
 init object with list of domaint. Automaticaly generates content blocker rule
 */
- (id)initWithDomains:(NSArray<NSString*> *)domains;

/////////////////////////////////////////////////////////////////////
#pragma mark Properties and public methods

/**
 add domain to list and to content blocker rule
 */
- (void) addDomain:(NSString *)domain;

/**
 list of domains
 */
@property (nonatomic) NSArray<NSString*> *domains;

/**
 Content blocker rule
 */
@property (nonatomic) ASDFilterRule *rule;

@end
