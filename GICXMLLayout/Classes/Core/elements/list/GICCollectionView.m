//
//  GICCollectionView.m
//  GICXMLLayout
//
//  Created by 龚海伟 on 2018/9/26.
//

#import "GICCollectionView.h"
#define RACWindowCount 10
#import "GICListItem.h"
#import "GICCollectionLayoutDelegate.h"

#import "GICNumberConverter.h"
#import "GICEdgeConverter.h"
#import "GICBoolConverter.h"
#import "GICListHeader.h"
#import "GICListFooter.h"

@interface GICCollectionView ()<ASCollectionDataSource,ASCollectionDelegate,ASCollectionViewLayoutInspecting>{
    NSMutableArray<GICListItem *> *listItems;
    BOOL t;
    id<RACSubscriber> insertItemsSubscriber;
    
    GICCollectionLayoutDelegate *layoutDelegate;
    
    
    GICListHeader *header;
    GICListFooter *footer;
}
@end

@implementation GICCollectionView
+(NSString *)gic_elementName{
    return @"collection-view";
}

+(instancetype)createElementWithXML:(GDataXMLElement *)xmlElement{
    GICCollectionLayoutDelegate *layoutDelegate = [[GICCollectionLayoutDelegate alloc] initWithNumberOfColumns:1 headerHeight:0.0];
    return [[self alloc] initWithLayoutDelegate:layoutDelegate layoutFacilitator:nil];
}

+(NSDictionary<NSString *,GICAttributeValueConverter *> *)gic_elementAttributs{
    return @{
             @"colums":[[GICNumberConverter alloc] initWithPropertySetter:^(NSObject *target, id value) {
                 ((GICCollectionView *)target)->layoutDelegate.layoutInfo.numberOfColumns=MAX(1, [value integerValue]);
             }],
             @"column-spacing":[[GICNumberConverter alloc] initWithPropertySetter:^(NSObject *target, id value) {
                 ((GICCollectionView *)target)->layoutDelegate.layoutInfo.columnSpacing=[value floatValue];
             }],
             @"auto-height":[[GICBoolConverter alloc] initWithPropertySetter:^(NSObject *target, id value) {
                 ((GICCollectionView *)target)->layoutDelegate.layoutInfo.autoChangeLayoutHieght=[value boolValue];
             }],
             @"inter-item-spacing":[[GICEdgeConverter alloc] initWithPropertySetter:^(NSObject *target, id value) {
                 [((GICCollectionView *)target)->layoutDelegate.layoutInfo setValue:value forKey:@"interItemSpacing"];
             }],
             @"separator-style":[[GICNumberConverter alloc] initWithPropertySetter:^(NSObject *target, id value) {
                 ((GICCollectionView *)target).separatorStyle = [value integerValue];
             }],
             @"show-ver-scroll":[[GICBoolConverter alloc] initWithPropertySetter:^(NSObject *target, id value) {
                 [(GICCollectionView *)target gic_safeView:^(UIView *view) {
                     [(UIScrollView *)view setShowsVerticalScrollIndicator:[value boolValue]];
                 }];
             }],
             @"show-hor-scroll":[[GICBoolConverter alloc] initWithPropertySetter:^(NSObject *target, id value) {
                 [(GICCollectionView *)target gic_safeView:^(UIView *view) {
                     [(UIScrollView *)view setShowsHorizontalScrollIndicator:[value boolValue]];
                 }];
             }],
             };
}

- (instancetype)initWithLayoutDelegate:(id<ASCollectionLayoutDelegate>)layoutDelegate layoutFacilitator:(id<ASCollectionViewLayoutFacilitatorProtocol>)layoutFacilitator
{
    
    self = [super initWithLayoutDelegate:layoutDelegate layoutFacilitator:layoutFacilitator];
    
    listItems = [NSMutableArray array];
    self.style.height = ASDimensionMake(0.1);
    self->layoutDelegate = (GICCollectionLayoutDelegate *)layoutDelegate;
    self->layoutDelegate.target = self;
    
    self.dataSource = self;
    self.delegate = self;
    self.layoutInspector = self;
    // 创建一个0.2秒的节流阀
    @weakify(self)
    [[[RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
        self->insertItemsSubscriber = subscriber;
        return nil;
    }] bufferWithTime:0.1 onScheduler:[RACScheduler mainThreadScheduler]] subscribeNext:^(RACTuple * _Nullable x) {
        @strongify(self)
        if(self){
            NSArray *insertArray = nil;
            // 每次只加载最多RACWindowCount 条数据，这样避免一次性加载过多的话会影响显示速度
            if(x.count<=RACWindowCount){
                insertArray = [x allObjects];
            }else{
                insertArray = [NSMutableArray array];
                [[x allObjects] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if(idx<RACWindowCount){
                        [(NSMutableArray *)insertArray addObject:obj];
                    }else{
                        [self->insertItemsSubscriber sendNext:obj];
                    }
                }];
            }
            
            NSInteger index = self->listItems.count;
            [self->listItems addObjectsFromArray:insertArray];
            if(index==0){
                [self reloadData];
            }else{
                NSMutableArray *mutArray=[NSMutableArray array];
                for(int i=0 ;i<insertArray.count;i++){
                    [mutArray addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                    index ++;
                }
                [self insertItemsAtIndexPaths:mutArray];
            }
        }
    }];
    return self;
}

-(id)gic_addSubElement:(id)subElement{
    if([subElement isKindOfClass:[GICListItem class]]){
        [subElement gic_ExtensionProperties].superElement = self;
        if(!self.isNodeLoaded){
            [listItems addObject:subElement];
        }else{
            [self->insertItemsSubscriber sendNext:subElement];
        }
        return subElement;
    }else if ([subElement isKindOfClass:[GICListHeader class]]){
        header = subElement;
        layoutDelegate.layoutInfo.headerHeight = header.style.height.value;
        NSAssert(layoutDelegate.layoutInfo.headerHeight>0, @"请显示设置header的height属性");
        [self registerSupplementaryNodeOfKind:UICollectionElementKindSectionHeader];
        return subElement;
    }else if ([subElement isKindOfClass:[GICListFooter class]]){
        footer = subElement;
        layoutDelegate.layoutInfo.footerHeight = footer.style.height.value;
        NSAssert(layoutDelegate.layoutInfo.footerHeight>0, @"请显示设置footer的height属性");
        [self registerSupplementaryNodeOfKind:UICollectionElementKindSectionFooter];
        return subElement;
    }
    else{
        return [super gic_addSubElement:subElement];
    }
}

-(void)gic_removeSubElements:(NSArray<GICListItem *> *)subElements{
    [super gic_removeSubElements:subElements];
    if(subElements.count==0)
        return;
    NSMutableArray *mutArray=[NSMutableArray array];
    for(id subElement in subElements){
        if([subElement isKindOfClass:[GICListItem class]]){
            [mutArray addObject:[NSIndexPath indexPathForRow:[listItems indexOfObject:subElement] inSection:0]];
        }
    }
    [listItems removeObjectsInArray:subElements];
    dispatch_async(dispatch_get_main_queue(), ^{
        if(self->listItems.count==0){
            [self reloadData];
        }else{
            [self deleteItemsAtIndexPaths:mutArray];
        }
    });
}

-(NSArray *)gic_subElements{
    NSMutableArray *elments = [listItems mutableCopy];
    if(header){
        [elments addObject:header];
    }
    
    if(footer){
        [elments addObject:footer];
    }
    return elments;
}


#pragma mark - ASCollectionNodeDelegate / ASCollectionNodeDataSource
//- (NSInteger)numberOfSectionsInCollectionNode:(ASCollectionNode *)collectionNode
//{
//    return 1;
//}
//
- (NSInteger)collectionNode:(ASCollectionNode *)collectionNode numberOfItemsInSection:(NSInteger)section
{
    return [listItems count];
}

- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
    GICListItem *item = [self->listItems objectAtIndex:indexPath.row];
    item.separatorStyle = self.separatorStyle;
    ASCellNode *(^cellNodeBlock)(void) = ^ASCellNode *() {
        [item prepareLayout];
        return item;
    };
    return cellNodeBlock;
}

- (ASCellNode *)collectionNode:(ASCollectionNode *)collectionNode nodeForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    // TODO:等后面支持了section后修改逻辑
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        return header;
    }else if ([kind isEqualToString:UICollectionElementKindSectionFooter]) {
        return footer;
    }
    return nil;
}

- (ASScrollDirection)scrollableDirections
{
    return ASScrollDirectionVerticalDirections;
}

- (ASSizeRange)collectionView:(nonnull ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(nonnull NSIndexPath *)indexPath {
    return ASSizeRangeZero;
}

- (NSUInteger)collectionView:(ASCollectionView *)collectionView supplementaryNodesOfKind:(NSString *)kind inSection:(NSUInteger)section
{
    // TODO:等后面支持了section后需要修改逻辑
    if([kind isEqualToString:UICollectionElementKindSectionHeader] && header){
        return 1;
    }else if([kind isEqualToString:UICollectionElementKindSectionFooter] && footer){
        return 1;
    }
    return 0;
}

-(void)collectionNode:(ASCollectionNode *)collectionNode didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    // 触发选中事件
    GICListItem *item = [collectionNode nodeForItemAtIndexPath:indexPath];
    [item.itemSelectEvent fire:nil];
}

-(id)gic_parseSubElementNotExist:(GDataXMLElement *)element{
    NSString *elName = [element name];
    if([elName isEqualToString:[GICListHeader gic_elementName]]){
        return  [GICListHeader new];
    }else if([elName isEqualToString:[GICListFooter gic_elementName]]){
        return  [GICListFooter new];
    }
    return [super gic_parseSubElementNotExist:element];
}

-(void)dealloc{
    [insertItemsSubscriber sendCompleted];
}
@end
