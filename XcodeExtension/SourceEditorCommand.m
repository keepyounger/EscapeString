//
//  SourceEditorCommand.m
//  XcodeExtension
//
//  Created by 李向阳 on 2017/1/6.
//  Copyright © 2017年 lixy. All rights reserved.
//

#import "SourceEditorCommand.h"

@interface SourceEditorCommand ()
@property (nonatomic, strong) XCSourceTextBuffer *buffer;
@property (nonatomic, assign) BOOL isUnescape;
@end

@implementation SourceEditorCommand

- (void)performCommandWithInvocation:(XCSourceEditorCommandInvocation *)invocation completionHandler:(void (^)(NSError * _Nullable nilOrError))completionHandler
{
    if ([invocation.commandIdentifier isEqualToString:@"Unescape"]) {
        self.isUnescape = YES;
    } else {
        self.isUnescape = NO;
    }
    
    self.buffer = invocation.buffer;
    [self escapeOrUnescapeString];
    completionHandler(nil);
}

- (void)escapeOrUnescapeString
{
    XCSourceTextRange *range = self.buffer.selections.firstObject;
    NSString *selectedString = @"";
    NSString *firstString = @"";
    NSString *lastString = @"";
    
    //没有任何选择 执行正则
    if (range.start.line == range.end.line && range.start.column==range.end.column) {
        
        NSString *lineString = self.buffer.lines[range.start.line];
        
        //只匹配objective-c
        NSString *regexString = @"@\"[^@]*\"";
        
        NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:regexString options:0 error:nil];
        NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:lineString options:0 range:NSMakeRange(0, lineString.length)];
        NSTextCheckingResult *result = matches.firstObject;
        selectedString = [lineString substringWithRange:NSMakeRange(result.range.location+2, result.range.length-3)];
        firstString = [lineString substringToIndex:result.range.location+2];
        lastString = [lineString substringFromIndex:result.range.location+result.range.length-1];
        
        
    } else
    //有选择就执行选择
    if (range.start.line == range.end.line) {
        selectedString = [self.buffer.lines[range.start.line] substringWithRange:NSMakeRange(range.start.column, range.end.column-range.start.column)];
        firstString = [self.buffer.lines[range.start.line] substringToIndex:range.start.column];
        lastString = [self.buffer.lines[range.end.line] substringFromIndex:range.end.column];

    } else {
        for (NSInteger i=range.start.line; i<=range.end.line; i++) {
            if (i==range.start.line) {
                selectedString = [NSString stringWithFormat:@"%@%@",selectedString,[[self.buffer.lines[i] substringFromIndex:range.start.column] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]]];
                selectedString = [selectedString stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
                firstString = [NSString stringWithFormat:@"%@%@",firstString,[self.buffer.lines[i] substringToIndex:range.start.column]];
                continue;
            }
            
            if (i == range.end.line) {
                selectedString = [NSString stringWithFormat:@"%@%@",selectedString,[[self.buffer.lines[i] substringToIndex:range.end.column] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]]];
                selectedString = [selectedString stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
                lastString = [NSString stringWithFormat:@"%@%@",lastString,[self.buffer.lines[i] substringFromIndex:range.end.column]];
                
                continue;
            }
            
            selectedString = [NSString stringWithFormat:@"%@%@",selectedString,[self.buffer.lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]]];
            selectedString = [selectedString stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
        }
    }
    
    NSInteger index = range.start.line;
    
    if (selectedString.length==0) {
        return;
    }
    
    if (self.isUnescape) {
        selectedString = [self unescapeString:selectedString];
    } else {
        selectedString = [self escapeString:selectedString];
    }
    
    [self.buffer.lines removeObjectsInRange:NSMakeRange(range.start.line, range.end.line-range.start.line+1)];
    [self.buffer.lines insertObject:[NSString stringWithFormat:@"%@%@%@", firstString, selectedString, lastString] atIndex:index];
    
    XCSourceTextRange *selection = [[XCSourceTextRange alloc] initWithStart:XCSourceTextPositionMake(index, 0) end:XCSourceTextPositionMake(index, 0)];
    [self.buffer.selections removeAllObjects];
    [self.buffer.selections insertObject:selection atIndex:0];
}

#pragma mark - String Helper

- (NSString *)escapeString:(NSString *)string {
    NSMutableString *result = [NSMutableString string];
    @try {
        NSUInteger length = [string length];
        for (NSUInteger i = 0; i < length; i++) {
            unichar uc = [string characterAtIndex:i];
            switch (uc) {
                case '\"': [result appendString:@"\\\""]; break;
                case '\'': [result appendString:@"\\\'"]; break;
                case '\\': [result appendString:@"\\\\"]; break;
                case '\t': [result appendString:@"\\t"]; break;
                case '\n': [result appendString:@"\\n"]; break;
                case '\r': [result appendString:@"\\r"]; break;
                case '\b': [result appendString:@"\\b"]; break;
                case '\f': [result appendString:@"\\f"]; break;
                default: {
                    if (uc < 0x20) {
                        [result appendFormat:@"\\u%04x", uc];
                    }
                    else {
                        [result appendFormat:@"%C", uc];
                    }
                } break;
            }
        }
        //        }
    }
    @catch (NSException *exception) {
        NSLog(@"Error while converting string: %@", exception);
    }
    return (NSString *)result;
}

#define nextUC ++i; if(i>=length) { break; }; uc = [string characterAtIndex:i];
- (NSString *)unescapeString:(NSString *)string {
    // NSScanner *scanner = [[NSScanner alloc] initWithString:string];
    NSMutableString *result = [NSMutableString string];
    NSUInteger length = [string length];
    for (NSUInteger i = 0; i < length; i++) {
        unichar uc = [string characterAtIndex:i];
        if(uc == '\\') {
            nextUC;
            switch (uc) {
                case '\"': [result appendString:@"\""]; break;
                case '\'': [result appendString:@"\'"]; break;
                case '\\': [result appendString:@"\\"]; break;
                case 't':  [result appendString:@"\t"]; break;
                case 'n':  [result appendString:@"\n"]; break;
                case 'r':  [result appendString:@"\r"]; break;
                case 'b':  [result appendString:@"\b"]; break;
                case 'f':  [result appendString:@"\f"]; break;
                case 'u': {
                    unichar hex[5]; hex[4] = 0;
                    nextUC; hex[0] = uc;
                    nextUC; hex[1] = uc;
                    nextUC; hex[2] = uc;
                    nextUC; hex[3] = uc;
                    
                } break;
                default: {
                    CFStringAppendCharacters((CFMutableStringRef)result, &uc, 1);
                } break;
            }
        }
        else {
            CFStringAppendCharacters((CFMutableStringRef)result, &uc, 1);
        }
    }
    return result;
}


@end
