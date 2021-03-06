#import "MVChatUserWatchRule.h"
#import "MVChatUser.h"
#import "MVChatUserPrivate.h"
#import "NSNotificationAdditions.h"
#import "MVUtilities.h"

#import <AGRegex/AGRegex.h>

NSString *MVChatUserWatchRuleMatchedNotification = @"MVChatUserWatchRuleMatchedNotification";
NSString *MVChatUserWatchRuleRemovedMatchedUserNotification = @"MVChatUserWatchRuleRemovedMatchedUserNotification";

@implementation MVChatUserWatchRule
- (id) initWithDictionaryRepresentation:(NSDictionary *) dictionary {
	if( ( self = [super init] ) ) {
		[self setUsername:[dictionary objectForKey:@"username"]];
		[self setNickname:[dictionary objectForKey:@"nickname"]];
		[self setRealName:[dictionary objectForKey:@"realName"]];
		[self setAddress:[dictionary objectForKey:@"address"]];
		[self setPublicKey:[dictionary objectForKey:@"publicKey"]];
		[self setInterim:[[dictionary objectForKey:@"interim"] boolValue]];
		[self setApplicableServerDomains:[dictionary objectForKey:@"applicableServerDomains"]];
	}

	return self;
}

- (void) dealloc {
	[_matchedChatUsers release];
	[_nickname release];
	[_nicknameRegex release];
	[_realName release];
	[_realNameRegex release];
	[_username release];
	[_usernameRegex release];
	[_address release];
	[_addressRegex release];
	[_publicKey release];
	[_applicableServerDomains release];

	_matchedChatUsers = nil;
	_nickname = nil;
	_nicknameRegex = nil;
	_realName = nil;
	_realNameRegex = nil;
	_username = nil;
	_usernameRegex = nil;
	_address = nil;
	_addressRegex = nil;
	_publicKey = nil;
	_applicableServerDomains = nil;

	[super dealloc];
}

- (id) copyWithZone:(NSZone *) zone {
	MVChatUserWatchRule *copy = [[MVChatUserWatchRule allocWithZone:zone] init];
	[self setUsername:[self username]];
	[self setNickname:[self nickname]];
	[self setRealName:[self realName]];
	[self setAddress:[self address]];
	[self setPublicKey:[self publicKey]];
	[self setInterim:[self isInterim]];
	[self setApplicableServerDomains:[self applicableServerDomains]];
	return copy;
}

- (NSDictionary *) dictionaryRepresentation {
	NSMutableDictionary *dictionary = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:5];
	if( _username ) [dictionary setObject:_username forKey:@"username"];
	if( _nickname ) [dictionary setObject:_nickname forKey:@"nickname"];
	if( _realName ) [dictionary setObject:_realName forKey:@"realName"];
	if( _address ) [dictionary setObject:_address forKey:@"address"];
	if( _publicKey ) [dictionary setObject:_publicKey forKey:@"publicKey"];
	if( _interim ) [dictionary setObject:[NSNumber numberWithBool:_interim] forKey:@"interim"];
	if( _applicableServerDomains ) [dictionary setObject:_applicableServerDomains forKey:@"applicableServerDomains"];
	return [dictionary autorelease];
}

- (BOOL) isEqual:(id) object {
	if( object == self ) return YES;
	if( ! object || ! [object isKindOfClass:[self class]] ) return NO;
	return [self isEqualToChatUserWatchRule:object];
}

- (BOOL) isEqualToChatUserWatchRule:(MVChatUserWatchRule *) anotherRule {
	if( ! anotherRule ) return NO;
	if( anotherRule == self ) return YES;

	if( ( ! [self nickname] && ! [anotherRule nickname] ) || ! [[self nickname] isEqualToString:[anotherRule nickname]] )
		return NO;

	if( ( ! [self username] && ! [anotherRule username] ) || ! [[self username] isEqualToString:[anotherRule username]] )
		return NO;

	if( ( ! [self realName] && ! [anotherRule realName] ) || ! [[self realName] isEqualToString:[anotherRule realName]] )
		return NO;

	if( ( ! [self address] && ! [anotherRule address] ) || ! [[self address] isEqualToString:[anotherRule address]] )
		return NO;

	if( ( ! [self publicKey] && ! [anotherRule publicKey] ) || ! [[self publicKey] isEqualToData:[anotherRule publicKey]] )
		return NO;

	return YES;
}

- (BOOL) matchChatUser:(MVChatUser *) user {
	if( ! user ) return NO;

	if( ! _matchedChatUsers )
		_matchedChatUsers = [[NSMutableSet allocWithZone:nil] initWithCapacity:10];

	@synchronized( _matchedChatUsers ) {
		if( [_matchedChatUsers containsObject:user] )
			return YES;
	}

	NSString *string = [user nickname];
	if( _nicknameRegex && ! string ) return NO;
	if( _nicknameRegex && ! [_nicknameRegex findInString:string] ) return NO;
	if( ! _nicknameRegex && _nickname && [_nickname length] && ! [_nickname isEqualToString:string] ) return NO;

	string = [user username];
	if( _usernameRegex && ! string ) return NO;
	if( _usernameRegex && ! [_usernameRegex findInString:string] ) return NO;
	if( ! _usernameRegex && _username && [_username length] && ! [_username isEqualToString:string] ) return NO;

	string = [user address];
	if( _addressRegex && ! string ) return NO;
	if( _addressRegex && ! [_addressRegex findInString:string] ) return NO;
	if( ! _addressRegex && _address && [_address length] && ! [_address isEqualToString:string] ) return NO;

	string = [user realName];
	if( _realNameRegex && ! string ) return NO;
	if( _realNameRegex && ! [_realNameRegex findInString:string] ) return NO;
	if( ! _realNameRegex && _realName && [_realName length] && ! [_realName isEqualToString:string] ) return NO;

	NSData *data = [user publicKey];
	if( _publicKey && [_publicKey length] && ! [_publicKey isEqualToData:data] ) return NO;

	@synchronized( _matchedChatUsers ) {
		if( ! [_matchedChatUsers containsObject:user] ) {
			[_matchedChatUsers addObject:user];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatUserWatchRuleMatchedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", nil]];
		}
	}

	return YES;
}

- (NSSet *) matchedChatUsers {
	@synchronized( _matchedChatUsers ) {
		return [NSSet setWithSet:_matchedChatUsers];
	} return nil;
}

- (void) removeMatchedUser:(MVChatUser *) user {
	@synchronized( _matchedChatUsers ) {
		if( [_matchedChatUsers containsObject:user] ) {
			[user retain];
			[_matchedChatUsers removeObject:user];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatUserWatchRuleRemovedMatchedUserNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", nil]];
			[user release];
		}
	}
}

- (void) removeMatchedUsersForConnection:(MVChatConnection *) connection {
	@synchronized( _matchedChatUsers ) {
		NSEnumerator *enumerator = [[[_matchedChatUsers copy] autorelease] objectEnumerator];
		MVChatUser *user = nil;

		while( ( user = [enumerator nextObject] ) ) {
			if( [[user connection] isEqual:connection] ) {
				[user retain];
				[_matchedChatUsers removeObject:user];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatUserWatchRuleRemovedMatchedUserNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", nil]];
				[user release];
			}
		}
	}
}

- (NSString *) nickname {
	return _nickname;
}

- (void) setNickname:(NSString *) newNickname {
	MVSafeCopyAssign( &_nickname, newNickname );

	id old = _nicknameRegex;
	if( _nickname && ( [_nickname length] > 2 ) && [_nickname hasPrefix:@"/"] && [_nickname hasSuffix:@"/"] )
		_nicknameRegex = [[AGRegex alloc] initWithPattern:[_nickname substringWithRange:NSMakeRange( 1, [_nickname length] - 2)] options:AGRegexCaseInsensitive];
	else _nicknameRegex = nil;
	[old release];
}

- (BOOL) nicknameIsRegularExpression {
	return ( _nicknameRegex ? YES : NO );
}

- (NSString *) realName {
	return _realName;
}

- (void) setRealName:(NSString *) newRealName {
	MVSafeCopyAssign( &_realName, newRealName );

	id old = _realNameRegex;
	if( _realName && ( [_realName length] > 2 ) && [_realName hasPrefix:@"/"] && [_realName hasSuffix:@"/"] )
		_realNameRegex = [[AGRegex alloc] initWithPattern:[_realName substringWithRange:NSMakeRange( 1, [_realName length] - 2)] options:AGRegexCaseInsensitive];
	else _realNameRegex = nil;
	[old release];
}

- (BOOL) realNameIsRegularExpression {
	return ( _realNameRegex ? YES : NO );
}

- (NSString *) username {
	return _username;
}

- (void) setUsername:(NSString *) newUsername {
	MVSafeCopyAssign( &_username, newUsername );

	id old = _usernameRegex;
	if( _username && ( [_username length] > 2 ) && [_username hasPrefix:@"/"] && [_username hasSuffix:@"/"] )
		_usernameRegex = [[AGRegex alloc] initWithPattern:[_username substringWithRange:NSMakeRange( 1, [_username length] - 2)] options:AGRegexCaseInsensitive];
	else _usernameRegex = nil;
	[old release];
}

- (BOOL) usernameIsRegularExpression {
	return ( _usernameRegex ? YES : NO );
}

- (NSString *) address {
	return _address;
}

- (void) setAddress:(NSString *) newAddress {
	MVSafeCopyAssign( &_address, newAddress );

	id old = _addressRegex;
	if( _address && ( [_address length] > 2 ) && [_address hasPrefix:@"/"] && [_address hasSuffix:@"/"] )
		_addressRegex = [[AGRegex alloc] initWithPattern:[_address substringWithRange:NSMakeRange( 1, [_address length] - 2)] options:AGRegexCaseInsensitive];
	else _addressRegex = nil;
	[old release];
}

- (BOOL) addressIsRegularExpression {
	return ( _addressRegex ? YES : NO );
}

- (NSData *) publicKey {
	return _publicKey;
}

- (void) setPublicKey:(NSData *) publicKey {
	MVSafeCopyAssign( &_publicKey, publicKey );
}

- (BOOL) isInterim {
	return _interim;
}

- (void) setInterim:(BOOL) interim {
	_interim = interim;
}

- (NSArray *) applicableServerDomains {
	return _applicableServerDomains;
}

- (void) setApplicableServerDomains:(NSArray *) serverDomains {
	MVSafeCopyAssign( &_applicableServerDomains, serverDomains );
}
@end
