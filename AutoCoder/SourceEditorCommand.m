//
//  SourceEditorCommand.m
//  createGetter
//
//  Created by 陈越东 on 2018/1/25.
//  Copyright © 2018年 microfastup. All rights reserved.
//

#import "SourceEditorCommand.h"
#import <Cocoa/Cocoa.h>

@interface SourceEditorCommand ()

@property (nonatomic, assign) NSInteger predicate;
@property (nonatomic, strong) NSMutableArray *indexsArray;

@property (nonatomic, strong) NSMutableArray *cellsArray;
@property (nonatomic, strong) NSMutableArray *headersArray;
@property (nonatomic, strong) NSMutableArray *footersArray;

@property (nonatomic, assign) BOOL isVc;

@end

@implementation SourceEditorCommand

- (void)performCommandWithInvocation:(XCSourceEditorCommandInvocation *)invocation completionHandler:(void (^)(NSError * _Nullable nilOrError))completionHandler
{
    self.predicate = NO;
    NSArray *stringArray = [NSArray arrayWithArray:invocation.buffer.lines];
    
    for (int i = 0; i < stringArray.count; i++) {
        
        if (!self.predicate) {
            [self predicateForImports:stringArray[i]];
            [self beginPredicate:stringArray[i]];
        } else {
            if ([self endPredicate:stringArray[i]]) {
                NSMutableArray *resultArray = [self makeResultStringArray];
                
                for (int i = (int)invocation.buffer.lines.count - 1; i > 0 ; i--) {
                    NSString *stringend = stringArray[i];
                    if ([stringend containsString:@"@end"]) {
                        for (int j = (int)resultArray.count - 1; j >= 0; j--) {
                            NSArray *array = resultArray[j];
                            for (int x = (int)(array.count - 1); x >= 0; x--) {
                                [invocation.buffer.lines insertObject:array[x] atIndex:i - 1];
                            }
                        }
                    } else if ([stringend containsString:@"@implementation"]) {
                        if (completionHandler) {
                            completionHandler(nil);
                        }
                        return;
                    }
                }
                
                if (completionHandler) {
                    completionHandler(nil);
                }
                return;
                
            } else {
                //没有匹配到 end  需要匹配property
                [self predicateForProperty:stringArray[i]];
                
            }
        }
    }
    completionHandler(nil);
}

#pragma mark -- Analyse Codes

- (void)predicateForImports:(NSString *)string
{
    if ([string containsString:@"#import"]) {
        
        if ([string containsString:@"Cell"]) {
            NSString *cellName = [string substringWithRange:NSMakeRange(9, string.length - 13)];
            [self.cellsArray addObject:cellName];
        } else if ([string containsString:@"Header"]) {
            NSString *headerName = [string substringWithRange:NSMakeRange(9, string.length - 13)];
            [self.headersArray addObject:headerName];
        } else if ([string containsString:@"Footer"]) {
            NSString *footerName = [string substringWithRange:NSMakeRange(9, string.length - 13)];
            [self.footersArray addObject:footerName];
        }
        
    }
}

- (void)predicateForProperty:(NSString *)string
{
    NSString *str = string;
    NSPredicate *pre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^@property.*;\\n$"];
    if ([pre evaluateWithObject:str]) {
        //这是一个property.
        if ([str containsString:@"*"] && ![str containsString:@"IBOutlet"] && ![str containsString:@"^"] && ![str containsString:@"//"]) {
            NSString *category = @"";
            NSString *name = @"";
            
            NSRange range1 = [str rangeOfString:@"\\).*\\*" options:NSRegularExpressionSearch];
            NSString *string1 = [str substringWithRange:range1];
            NSRange range2 = [string1 rangeOfString:@"[a-zA-Z0-9_]+" options:NSRegularExpressionSearch];
            category = [string1 substringWithRange:range2];
            
            NSRange range3 = [str rangeOfString:@"\\*.*;" options:NSRegularExpressionSearch];
            NSString *string2 = [str substringWithRange:range3];
            NSRange range4 = [string2 rangeOfString:@"[a-zA-Z0-9_]+" options:NSRegularExpressionSearch];
            name = [string2 substringWithRange:range4];
            
            NSDictionary *dic = @{@"category" : category, @"name" : name};
            [self.indexsArray addObject:dic];
        }
    }
}


- (void)beginPredicate:(NSString *)string
{
    NSString *str = string;
    if ([str containsString:@"@interface"]) {
        self.predicate = YES;
        // 简单判断是 vc 还是 view
        if ([str containsString:@"ViewController"]) {
            self.isVc = YES;
        } else {
            self.isVc = NO;
        }
    }
}

- (BOOL)endPredicate:(NSString *)string
{
    if ([string containsString:@"@end"]) {
        self.predicate = NO;
        return YES;
    }
    return NO;
}


#pragma mark -- Add Codes

- (NSMutableArray *)makeResultStringArray
{
    NSMutableArray *itemsArray = [[NSMutableArray alloc] init];
    
    if (!self.isVc) {
        [itemsArray addObjectsFromArray:[self makeInitStringArray]];
    }
    [itemsArray addObjectsFromArray:[self makeConfigStringArray]];
    [itemsArray addObjectsFromArray:[self makeActionsStringArray]];
    [itemsArray addObjectsFromArray:[self makeGettersStringArray]];
    
    return itemsArray;
}

// 自动打上 init 代码
- (NSMutableArray *)makeInitStringArray
{
    NSMutableArray *itemsArray = [[NSMutableArray alloc] init];
    
    NSString *line0 = [NSString stringWithFormat:@""];
    NSString *line1 = [NSString stringWithFormat:@"- (instancetype)initWithFrame:(CGRect)frame"];
    NSString *line2 = [NSString stringWithFormat:@"{"];
    NSString *line3 = [NSString stringWithFormat:@"    if (self = [super initWithFrame:frame]) {"];
    NSString *line4 = [NSString stringWithFormat:@"        [self configSubViews];"];
    NSString *line5 = [NSString stringWithFormat:@"    }"];
    NSString *line6 = [NSString stringWithFormat:@"    return self;"];
    NSString *line7 = [NSString stringWithFormat:@"}"];
    
    NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, line1, line2, line3, line4, line5, line6, line7, nil];
    
    [itemsArray addObject:lineArrays];
    
    return itemsArray;
}

// 自动打上 configSubViews 代码
- (NSMutableArray *)makeConfigStringArray
{
    NSMutableArray *itemsArray = [[NSMutableArray alloc] init];
    
    NSString *line0 = [NSString stringWithFormat:@""];
    NSString *line1 = [NSString stringWithFormat:@"- (void)configSubViews"];
    NSString *line2 = [NSString stringWithFormat:@"{"];
    NSMutableArray *lineArrays0 = [[NSMutableArray alloc] initWithObjects:line0, line1, line2, nil];
    [itemsArray addObject:lineArrays0];
    
    for (int i = 0; i < self.indexsArray.count; i++) {
        
        NSString *nameStr = self.indexsArray[i][@"name"];
        
        NSString *line0 = nil;
        if (self.isVc) {
            line0 = [NSString stringWithFormat:@"    [self.view addSubview:self.%@];", nameStr];
        } else {
            line0 = [NSString stringWithFormat:@"    [self addSubview:self.%@];", nameStr];
        }
        
        NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, nil];
        [itemsArray addObject:lineArrays];
    }
    
    for (int i = 0; i < self.indexsArray.count; i++) {
        
        NSString *nameStr = self.indexsArray[i][@"name"];
        
        NSString *line0 = [NSString stringWithFormat:@"    [self.%@ mas_makeConstraints:^(MASConstraintMaker *make) {", nameStr];
        NSString *line1 = [NSString stringWithFormat:@""];
        NSString *line2 = [NSString stringWithFormat:@"    }];"];
        
        NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, line1, line2, nil];
        [itemsArray addObject:lineArrays];
    }
    
    NSString *line3 = [NSString stringWithFormat:@"}"];
    NSMutableArray *lineArrays1 = [[NSMutableArray alloc] initWithObjects:line3, nil];
    [itemsArray addObject:lineArrays1];
    
    return itemsArray;
}

// 自动打上 actions 代码

- (NSMutableArray *)makeActionsStringArray
{
    NSMutableArray *itemsArray = [[NSMutableArray alloc] init];
    
    BOOL hasAddPragma = NO;
    
    for (int i = 0; i < self.indexsArray.count; i++) {
        
        NSString *categoryStr = self.indexsArray[i][@"category"];
        NSString *nameStr = self.indexsArray[i][@"name"];
        
        if ([categoryStr isEqualToString:[NSString stringWithFormat:@"UIButton"]]) {
            
            //添加方法
            NSString *actionf2 = [NSString stringWithFormat:@""];
            NSString *actionf1 = [NSString stringWithFormat:@"#pragma mark -- Actions"];
            NSString *action0 = [NSString stringWithFormat:@""];
            NSString *action1 = [NSString stringWithFormat:@"- (void)%@Action", nameStr];
            NSString *action2 = [NSString stringWithFormat:@"{"];
            NSString *action3 = [NSString stringWithFormat:@"}"];
            
            if (hasAddPragma) {
                NSMutableArray *actionArrays = [[NSMutableArray alloc] initWithObjects:action0, action1, action2, action3, nil];
                [itemsArray insertObject:actionArrays atIndex:1];
            } else {
                hasAddPragma = YES;
                NSMutableArray *actionArrays = [[NSMutableArray alloc] initWithObjects:actionf2, actionf1, action0, action1, action2, action3, nil];
                [itemsArray insertObject:actionArrays atIndex:0];
            }
            
        }
    }
    return itemsArray;
}

// 自动打上 getters 代码
- (NSMutableArray *)makeGettersStringArray
{
    NSMutableArray *itemsArray = [[NSMutableArray alloc] init];
    
    NSString *line0 = [NSString stringWithFormat:@""];
    NSString *line1 = [NSString stringWithFormat:@"#pragma mark -- Getters"];
    NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, line1, nil];
    [itemsArray addObject:lineArrays];
    
    BOOL hasAddCollectionViewPragma = NO;
    
    for (int i = 0; i < self.indexsArray.count; i++) {
        
        NSString *categoryStr = self.indexsArray[i][@"category"];
        NSString *nameStr = self.indexsArray[i][@"name"];
        
        if ([categoryStr isEqualToString:[NSString stringWithFormat:@"UILabel"]]) {
            NSString *line0 = [NSString stringWithFormat:@""];
            NSString *line1 = [NSString stringWithFormat:@"- (%@ *)%@", categoryStr, nameStr];
            NSString *line2 = [NSString stringWithFormat:@"{"];
            NSString *line3 = [NSString stringWithFormat:@"    if (!_%@) {", nameStr];
            NSString *line4 = [NSString stringWithFormat:@"        _%@ = [[%@ alloc] init];", nameStr, categoryStr];
            NSString *line5 = [NSString stringWithFormat:@"        _%@.font = ;", nameStr];
            NSString *line6 = [NSString stringWithFormat:@"        _%@.textColor = ;", nameStr];
            NSString *line20 = [NSString stringWithFormat:@"    }"];
            NSString *line21 = [NSString stringWithFormat:@"    return _%@;", nameStr];
            NSString *line22 = [NSString stringWithFormat:@"}"];
            
            NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, line1, line2, line3, line4, line5, line6, line20, line21, line22, nil];
            [itemsArray addObject:lineArrays];
        } else if ([categoryStr isEqualToString:[NSString stringWithFormat:@"UIButton"]]) {
            NSString *line0 = [NSString stringWithFormat:@""];
            NSString *line1 = [NSString stringWithFormat:@"- (%@ *)%@", categoryStr, nameStr];
            NSString *line2 = [NSString stringWithFormat:@"{"];
            NSString *line3 = [NSString stringWithFormat:@"    if (!_%@) {", nameStr];
            NSString *line4 = [NSString stringWithFormat:@"        _%@ = [[%@ alloc] init];", nameStr, categoryStr];
            NSString *line5 = [NSString stringWithFormat:@"        _%@.titleLabel.font = ;", nameStr];
            NSString *line6 = [NSString stringWithFormat:@"        [_%@ setTitle:  forState:UIControlStateNormal];", nameStr];
            NSString *line7 = [NSString stringWithFormat:@"        [_%@ setTitleColor:  forState:UIControlStateNormal];", nameStr];
            NSString *line8 = [NSString stringWithFormat:@"        [_%@ setImage:[UIImage imageNamed: ] forState:UIControlStateNormal];", nameStr];
            NSString *line9 = [NSString stringWithFormat:@"        [_%@ addTarget:self action:@selector(%@Action) forControlEvents:UIControlEventTouchUpInside];", nameStr, nameStr];
            
            NSString *line20 = [NSString stringWithFormat:@"    }"];
            NSString *line21 = [NSString stringWithFormat:@"    return _%@;", nameStr];
            NSString *line22 = [NSString stringWithFormat:@"}"];
            
            NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, line1, line2, line3, line4, line5, line6, line7, line8, line9, line20, line21, line22, nil];
            [itemsArray addObject:lineArrays];
            
        } else if ([categoryStr isEqualToString:[NSString stringWithFormat:@"UICollectionView"]]) {
            NSString *line0 = [NSString stringWithFormat:@""];
            NSString *line1 = [NSString stringWithFormat:@"- (%@ *)%@", categoryStr, nameStr];
            NSString *line2 = [NSString stringWithFormat:@"{"];
            NSString *line3 = [NSString stringWithFormat:@"    if (!_%@) {", nameStr];
            
            NSString *line4 = [NSString stringWithFormat:@"        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];"];
            NSString *line5 = [NSString stringWithFormat:@"        layout.itemSize = CGSizeMake( ,  );"];
            NSString *line6 = [NSString stringWithFormat:@"        layout.minimumLineSpacing = ;"];
            NSString *line7 = [NSString stringWithFormat:@"        layout.minimumInteritemSpacing = ;"];
            NSString *line8 = [NSString stringWithFormat:@"        layout.sectionInset = UIEdgeInsetsMake( , , , );"];
            NSString *line9 = [NSString stringWithFormat:@""];
            NSString *line10 = [NSString stringWithFormat:@"        _%@ = [[%@ alloc] initWithFrame:CGRectZero collectionViewLayout:layout];", nameStr, categoryStr];
            NSString *line11 = [NSString stringWithFormat:@"        _%@.delegate = self;", nameStr];
            NSString *line12 = [NSString stringWithFormat:@"        _%@.dataSource = self;", nameStr];
            NSString *line13 = [NSString stringWithFormat:@"        _%@.backgroundColor = [UIColor clearColor];", nameStr];
            
            NSMutableArray *line14Array = [NSMutableArray array];
            for (NSString *cellName in self.cellsArray) {
                NSString *line14 = [NSString stringWithFormat:@"        [_%@ registerClass:[%@ class] forCellWithReuseIdentifier:[%@ reuseIdentifier]];", nameStr, cellName, cellName];
                [line14Array addObject:line14];
            }
            for (NSString *headerName in self.headersArray) {
                NSString *line14 = [NSString stringWithFormat:@"        [_%@ registerClass:[%@ class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:[%@ reuseIdentifier]];", nameStr, headerName, headerName];
                [line14Array addObject:line14];
            }
            for (NSString *footerName in self.footersArray) {
                NSString *line14 = [NSString stringWithFormat:@"        [_%@ registerClass:[%@ class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:[%@ reuseIdentifier]];", nameStr, footerName, footerName];
                [line14Array addObject:line14];
            }
            
            NSString *line15 = [NSString stringWithFormat:@"    }"];
            NSString *line16 = [NSString stringWithFormat:@"    return _%@;", nameStr];
            NSString *line17 = [NSString stringWithFormat:@"}"];
            
            NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, line1, line2, line3, line4, line5, line6, line7, line8, line9, line10, line11, line12, line13, nil];
            [lineArrays addObjectsFromArray:line14Array];
            [lineArrays addObjectsFromArray:@[line15, line16, line17]];
            [itemsArray addObject:lineArrays];
            
            //添加datasource，delegate方法
            if (hasAddCollectionViewPragma) {
                continue;
            }
            hasAddCollectionViewPragma = YES;
            
            //添加方法
            NSString *action0 = [NSString stringWithFormat:@""];
            NSString *action1 = [NSString stringWithFormat:@"#pragma mark -- UICollectionView"];
            NSString *action1to2 = [NSString stringWithFormat:@""];
            NSString *action2 = [NSString stringWithFormat:@"- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section"];
            NSString *action3 = [NSString stringWithFormat:@"{"];
            NSString *action4 = [NSString stringWithFormat:@"    return 0;"];
            NSString *action5 = [NSString stringWithFormat:@"}"];
            NSString *action6 = [NSString stringWithFormat:@""];
            NSString *action7 = [NSString stringWithFormat:@"- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath"];
            NSString *action8 = [NSString stringWithFormat:@"{"];
            
            NSString *cellName = @"";
            if (self.cellsArray.count) {
                cellName = self.cellsArray.firstObject;
            }
            NSString *action9 = [NSString stringWithFormat:@"    %@ *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[%@ reuseIdentifier] forIndexPath:indexPath];", cellName, cellName];
            
            NSString *action10 = [NSString stringWithFormat:@"    return cell;"];
            NSString *action11 = [NSString stringWithFormat:@"}"];
            NSString *action12 = [NSString stringWithFormat:@""];
            NSString *action13 = [NSString stringWithFormat:@"- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath"];
            NSString *action14 = [NSString stringWithFormat:@"{"];
            NSString *action15 = [NSString stringWithFormat:@"}"];
            
            NSMutableArray *actionArrays = [[NSMutableArray alloc] initWithObjects:action0, action1, action1to2, action2, action3, action4, action5, action6, action7, action8, action9, action10, action11, action12, action13, action14, action15, nil];
            [itemsArray insertObject:actionArrays atIndex:0];
            
        } else {
            NSString *line0 = [NSString stringWithFormat:@""];
            NSString *line1 = [NSString stringWithFormat:@"- (%@ *)%@", categoryStr, nameStr];
            NSString *line2 = [NSString stringWithFormat:@"{"];
            NSString *line3 = [NSString stringWithFormat:@"    if (!_%@) {", nameStr];
            NSString *line4 = [NSString stringWithFormat:@"        _%@ = [[%@ alloc] init];", nameStr, categoryStr];
            NSString *line5 = [NSString stringWithFormat:@"    }"];
            NSString *line6 = [NSString stringWithFormat:@"    return _%@;", nameStr];
            NSString *line7 = [NSString stringWithFormat:@"}"];
            
            NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, line1, line2, line3, line4, line5, line6, line7, nil];
            [itemsArray addObject:lineArrays];
        }
    }
    return itemsArray;
}

#pragma mark -- Getters

- (NSMutableArray *)indexsArray
{
    if (!_indexsArray) {
        _indexsArray = [[NSMutableArray alloc] init];
    }
    return _indexsArray;
}

- (NSMutableArray *)cellsArray
{
    if (!_cellsArray) {
        _cellsArray = [NSMutableArray array];
    }
    return _cellsArray;
}

- (NSMutableArray *)headersArray
{
    if (!_headersArray) {
        _headersArray = [NSMutableArray array];
    }
    return _headersArray;
}

- (NSMutableArray *)footersArray
{
    if (!_footersArray) {
        _footersArray = [NSMutableArray array];
    }
    return _footersArray;
}

@end
