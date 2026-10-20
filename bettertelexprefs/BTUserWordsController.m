#import "BTUserWordsController.h"
#import "BTPrefsStore.h"
#import <Preferences/PSSpecifier.h>

// Đánh dấu ô là một từ trong danh sách (chỉ những ô này mới xoá được).
static NSString *const kBTWordProperty = @"btWord";

@implementation BTUserWordsController

- (NSArray *)specifiers {
	if (!_specifiers) {
		NSMutableArray *specifiers = [NSMutableArray array];

		PSSpecifier *addGroup = [PSSpecifier emptyGroupSpecifier];
		[addGroup setProperty:@"Nhập nhiều từ một lần bằng cách cách nhau bởi dấu cách hoặc dấu phẩy. Vuốt sang trái để xoá."
			forKey:@"footerText"];
		[specifiers addObject:addGroup];

		PSSpecifier *add = [PSSpecifier preferenceSpecifierNamed:@"Thêm từ…" target:self set:nil get:nil
			detail:nil cell:PSButtonCell edit:nil];
		add.buttonAction = @selector(addWords);
		[specifiers addObject:add];

		NSArray<NSString *> *words = [BTPrefsStore userWords];
		NSString *title = words.count ? [NSString stringWithFormat:@"%lu từ", (unsigned long)words.count] : @"Chưa có từ nào";
		[specifiers addObject:[PSSpecifier groupSpecifierWithName:title]];
		for (NSString *word in words) {
			PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:word target:self set:nil get:nil
				detail:nil cell:PSStaticTextCell edit:nil];
			[item setProperty:word forKey:kBTWordProperty];
			[specifiers addObject:item];
		}
		_specifiers = specifiers;
	}
	return _specifiers;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Từ điển cá nhân";
}

// Dựng lại toàn bộ danh sách từ file cài đặt (reloadSpecifiers không tự gọi lại -specifiers khi _specifiers còn).
- (void)reloadWords {
	_specifiers = nil;
	[self reloadSpecifiers];
}

- (void)addWords {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thêm từ"
		message:@"Cách nhau bằng dấu cách hoặc dấu phẩy" preferredStyle:UIAlertControllerStyleAlert];
	[alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
		field.placeholder = @"vd: quí ừm Đắc";
		field.autocapitalizationType = UITextAutocapitalizationTypeNone;
		field.autocorrectionType = UITextAutocorrectionTypeNo;
	}];
	[alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
	__weak typeof(self) weakSelf = self;
	__weak UIAlertController *weakAlert = alert;
	[alert addAction:[UIAlertAction actionWithTitle:@"Thêm" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		NSString *text = weakAlert.textFields.firstObject.text ?: @"";
		NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@" ,\n\t"];
		NSArray<NSString *> *input = [text componentsSeparatedByCharactersInSet:separators];
		[BTPrefsStore setUserWords:[[BTPrefsStore userWords] arrayByAddingObjectsFromArray:input]];
		[weakSelf reloadWords];
	}]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return [[self specifierAtIndexPath:indexPath] propertyForKey:kBTWordProperty] != nil;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [self tableView:tableView canEditRowAtIndexPath:indexPath]
		? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *word = [[self specifierAtIndexPath:indexPath] propertyForKey:kBTWordProperty];
	if (style != UITableViewCellEditingStyleDelete || !word)
		return;
	NSMutableArray<NSString *> *words = [[BTPrefsStore userWords] mutableCopy];
	[words removeObject:word];
	[BTPrefsStore setUserWords:words];
	[self reloadWords];
}

@end
