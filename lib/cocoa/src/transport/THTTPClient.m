#import "THTTPClient.h"
#import "TTransportException.h"

@implementation THTTPClient


- (void) setupRequest
{
  if (mRequest != nil) {
    [mRequest release];
  }
  
  // set up our request object that we'll use for each request
  mRequest = [[NSMutableURLRequest alloc] initWithURL: mURL];
  [mRequest setHTTPMethod: @"POST"];
  [mRequest setValue: @"application/x-thrift" forHTTPHeaderField: @"Content-Type"];
  [mRequest setValue: @"application/x-thrift" forHTTPHeaderField: @"Accept"];
  [mRequest setValue: @"Cocoa/THTTPClient" forHTTPHeaderField: @"User-Agent"];
  [mRequest setCachePolicy: NSURLRequestReloadIgnoringCacheData];
}


- (id) initWithURL: (NSURL *) aURL
{
  self = [super init];
  mURL = [aURL retain];

  [self setupRequest];

  // create our request data buffer
  mRequestData = [[NSMutableData alloc] initWithCapacity: 1024];

  return self;
}


- (id) initWithURL: (NSURL *) aURL 
           timeout: (int) timeout
{
  self = [self initWithURL: aURL];

  [mRequest setTimeoutInterval: timeout];

  return self;
}


- (void) setURL: (NSURL *) aURL
{
  [aURL retain];
  [mURL release];
  mURL = aURL;
  
  [self setupRequest];
}


- (void) dealloc
{
  [mURL release];
  [mRequest release];
  [mRequestData release];
  [mResponseData release];
  [super dealloc];
}


- (int) readAll: (uint8_t *) buf offset: (int) off length: (int) len
{
  NSRange r;
  r.location = mResponseDataOffset;
  r.length = len;

  [mResponseData getBytes: buf+off range: r];
  mResponseDataOffset += len;

  return len;
}


- (void) write: (const uint8_t *) data offset: (unsigned int) offset length: (unsigned int) length
{
  [mRequestData appendBytes: data+offset length: length];
}


- (void) flush
{
  [mRequest setHTTPBody: mRequestData]; // not sure if it copies the data

  // make the HTTP request
  NSURLResponse * response;
  NSError * error;
  NSData * responseData = 
    [NSURLConnection sendSynchronousRequest: mRequest returningResponse: &response error: &error];

  [mRequestData setLength: 0];

  if (responseData == nil) {
    @throw [TTransportException exceptionWithName: @"TTransportException"
                                reason: @"Could not make HTTP request"
                                error: error];
  }
  if (![response isKindOfClass: [NSHTTPURLResponse class]]) {
    @throw [TTransportException exceptionWithName: @"TTransportException"
                                           reason: @"Unexpected NSURLResponse type"];
  }

  NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *) response;
  if ([httpResponse statusCode] != 200) {
    @throw [TTransportException exceptionWithName: @"TTransportException"
                                           reason: [NSString stringWithFormat: @"Bad response from HTTP server: %d", 
                                                    [httpResponse statusCode]]];
  }
                                
  // phew!
  [mResponseData release];
  mResponseData = [responseData retain];
  mResponseDataOffset = 0;
}


@end
