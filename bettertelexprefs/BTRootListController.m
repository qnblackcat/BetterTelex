#import "BTRootListController.h"
#import "BTPrefsStore.h"
#import <Preferences/PSSpecifier.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "../BTPrefs.h"

@implementation BTRootListController

- (NSArray *)specifiers {
	if (!_specifiers)
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	return _specifiers;
}

static BOOL BTIsOurs(PSSpecifier *specifier) {
	return [specifier.properties[@"defaults"] isEqualToString:@"com.qn.bettertelex"]
		&& specifier.properties[@"key"] != nil;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
	if (!BTIsOurs(specifier))
		return [super readPreferenceValue:specifier];
	return [BTPrefsStore load][specifier.properties[@"key"]] ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	if (!BTIsOurs(specifier)) {
		[super setPreferenceValue:value specifier:specifier];
		return;
	}
	[BTPrefsStore setObject:value forKey:specifier.properties[@"key"]];
}

// Ô Credits / Source code: mở thuộc tính "url" của ô trong Root.plist.
- (void)openURL:(PSSpecifier *)specifier {
	NSURL *url = [NSURL URLWithString:specifier.properties[@"url"]];
	if (url)
		[[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message
		preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
	[self presentViewController:alert animated:YES completion:nil];
}

// File xuất ra là plist bọc toàn bộ cài đặt (cả từ điển cá nhân), kèm dấu hiệu để không nhập nhầm plist khác.
- (void)exportSettingsTapped:(PSSpecifier *)specifier {
	NSDictionary *backup = @{
		@"BetterTelexSettings": @1,
		@"preferences": [BTPrefsStore load]
	};

	NSError *error = nil;
	NSData *data = [NSPropertyListSerialization dataWithPropertyList:backup format:NSPropertyListXMLFormat_v1_0
		options:0 error:&error];
	if (!data) {
		[self showAlertWithTitle:@"Xuất thất bại" message:error.localizedDescription];
		return;
	}
	[self shareData:data name:@"BetterTelex Settings.plist"];
}

- (void)shareData:(NSData *)data name:(NSString *)name {
	NSError *error = nil;
	NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
	if (![data writeToURL:url options:NSDataWritingAtomic error:&error]) {
		[self showAlertWithTitle:@"Không chia sẻ được" message:error.localizedDescription];
		return;
	}

	UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
	share.popoverPresentationController.sourceView = self.view;
	share.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
		CGRectGetMidY(self.view.bounds), 0, 0);
	[self presentViewController:share animated:YES completion:nil];
}

- (void)importSettingsTapped:(PSSpecifier *)specifier {
	UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
		initForOpeningContentTypes:@[UTTypePropertyList] asCopy:YES];
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
	NSData *data = [NSData dataWithContentsOfURL:urls.firstObject];
	id backup = data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable
		format:NULL error:NULL] : nil;
	NSDictionary *values = [backup isKindOfClass:NSDictionary.class] ? backup[@"preferences"] : nil;
	if (![backup isKindOfClass:NSDictionary.class] || backup[@"BetterTelexSettings"] == nil
		|| ![values isKindOfClass:NSDictionary.class]) {
		[self showAlertWithTitle:@"Nhập thất bại" message:@"File này không phải bản sao lưu cài đặt BetterTelex."];
		return;
	}

	NSArray *words = values[BT_KEY_USER_WORDS];
	NSUInteger count = [words isKindOfClass:NSArray.class] ? words.count : 0;
	UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Nhập cài đặt"
		message:[NSString stringWithFormat:@"Toàn bộ cài đặt BetterTelex hiện tại, cả từ điển cá nhân, sẽ được thay bằng file này (%lu từ cá nhân). Tiếp tục?",
			(unsigned long)count]
		preferredStyle:UIAlertControllerStyleAlert];
	[confirm addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
	[confirm addAction:[UIAlertAction actionWithTitle:@"Nhập" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
		[BTPrefsStore replaceAll:values];
		[self reloadSpecifiers];
	}]];
	// Picker có thể vẫn đang đóng, nên đợi xong mới hiện hộp xác nhận.
	dispatch_async(dispatch_get_main_queue(), ^{
		[self presentViewController:confirm animated:YES completion:nil];
	});
}

@end
