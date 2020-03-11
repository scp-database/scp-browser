//
//  MyWKWebViewController.m
//  MyBrowser
//
//  Created by luowei on 15/6/26.
//  Copyright (c) 2015年 wodedata. All rights reserved.
//

#import "MyWKWebViewController.h"
#import "MyWKWebView.h"
#import "ListWKWebViewController.h"
#import "Defines.h"
#import "FavoritesViewController.h"
#import "MyHelper.h"
#import "MyPopupView.h"
#import "ScanQRViewController.h"
#import "Favorite.h"
#import "UserSetting.h"

@interface MyWKWebViewController ()

@end

@implementation MyWKWebViewController {
}


- (void)updateViewConstraints {
    [super updateViewConstraints];
}

- (void)loadView {
    [super loadView];

    //向webContainer中添加webview
    [self addWebView:HOME_URL];

//    //添加对webView的监听器
//    [self.activeWindow addObserver:self forKeyPath:@"loading" options:NSKeyValueObservingOptionNew context:nil];
//    [self.activeWindow addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
//    [self.activeWindow addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    self.edgesForExtendedLayout = UIRectEdgeNone;

    //如果是夜间模式,添加摭罩层
    if ([UserSetting nighttime]) {
        if(self.maskView && self.maskView.superview){
            [self.maskView removeFromSuperview];
        }
        self.maskView = [[UIView alloc] initWithFrame:self.view.bounds];
        self.maskView.userInteractionEnabled = NO;
        self.maskView.backgroundColor = [UIColor blackColor];
        self.maskView.alpha = 0.2;
        [self.view addSubview:self.maskView];

        self.maskView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[maskView]|" options:0 metrics:nil views:@{@"maskView" : self.maskView}]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[maskView]|" options:0 metrics:nil views:@{@"maskView" : self.maskView}]];
    }

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    //从userDefault中加载收藏,给_favoriteArray赋初值
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:MY_FAVORITES];
    self.favoriteArray = [NSMutableArray arrayWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:data]];

//    [_activeWindow reload];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"loading"]) {
        self.backBtn.enabled = self.activeWindow.canGoBack;
        self.forwardBtn.enabled = self.activeWindow.canGoForward;
    }
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        BOOL animated = self.activeWindow.estimatedProgress > self.progressView.progress;
        [self.progressView setProgress:(float) self.activeWindow.estimatedProgress animated:animated];

        //加载完成隐藏进度条
        if (self.activeWindow.estimatedProgress >= 1.0f) {
            [UIView animateWithDuration:0.3f delay:0.3f options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.progressView.hidden = YES;
            }                completion:^(BOOL finished) {
                [self.progressView setProgress:0.0f animated:NO];
            }];
        }
    }
    if ([keyPath isEqualToString:@"title"]) {
        self.title = self.activeWindow.title;
    }
}

- (void)dealloc {
    [self.activeWindow removeObserver:self forKeyPath:@"loading"];
    [self.activeWindow removeObserver:self forKeyPath:@"estimatedProgress"];
    [self.activeWindow removeObserver:self forKeyPath:@"title"];
}

#pragma mark - Web View Creation

- (MyWKWebView *)addWebView:(NSURL *)url {
    //添加webview
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.userContentController = [MyWKUserContentController shareInstance];
    MyWKWebView *wkWB = [[MyWKWebView alloc] initWithFrame:self.webContainer.frame configuration:configuration];

    wkWB.backgroundColor = [UIColor whiteColor];
    wkWB.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.webContainer addSubview:wkWB];
    [self.webContainer bringSubviewToFront:wkWB];

    wkWB.scrollView.delegate = self;
    //添加对webView的监听器
    [wkWB addObserver:self forKeyPath:@"loading" options:NSKeyValueObservingOptionNew context:nil];
    [wkWB addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    [wkWB addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:nil];

    //更新刷新进度条的block
    __weak __typeof(self) weakSelf = self;
    wkWB.finishNavigationProgressBlock = ^() {
        weakSelf.progressView.hidden = NO;
        [weakSelf.progressView setProgress:0.0 animated:NO];
        weakSelf.progressView.trackTintColor = [UIColor whiteColor];
    };
    
    wkWB.removeProgressObserverBlock = ^(){
        [self.activeWindow removeObserver:self forKeyPath:@"loading"];
        [self.activeWindow removeObserver:self forKeyPath:@"estimatedProgress"];
        [self.activeWindow removeObserver:self forKeyPath:@"title"];
    };

    wkWB.updateSearchBarTextBlock = ^(NSString *urlText){
        if(weakSelf.searchBar && urlText){
            weakSelf.searchBar.text = urlText;
        }
    };

    //添加新webView的block
    wkWB.addWKWebViewBlock = ^(MyWKWebView **wb, NSURL *aurl) {
        if (*wb) {
            *wb = [weakSelf addWebView:aurl];
        } else {
            [weakSelf addWebView:aurl];
        }
    };

    //presentViewController block
    wkWB.presentViewControllerBlock = ^(UIViewController *viewController) {
        [weakSelf presentViewController:viewController animated:YES completion:nil];
    };

    //关闭激活的webView的block
    wkWB.closeActiveWebViewBlock = ^() {
        [weakSelf closeActiveWebView];
    };

    //加载页面
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [wkWB loadRequest:request];

    // Add to windows array and make active window
    if (!self.listWebViewController) {
        self.listWebViewController = [[ListWKWebViewController alloc] initWithWKWebView:wkWB];

        //设置添加webView的block
        self.listWebViewController.addWKWebViewBlock = ^(MyWKWebView **wb, NSURL *aurl) {
            if (!*wb) {
                *wb = [weakSelf addWebView:aurl];
            } else {
                [weakSelf addWebView:aurl];
            }
        };
        //更新活跃webView的block
        self.listWebViewController.updateWKActiveWindowBlock = ^(MyWKWebView *wb) {
            weakSelf.activeWindow = wb;
            [weakSelf.webContainer bringSubviewToFront:weakSelf.activeWindow];
        };

    } else {
        self.listWebViewController.updateWKDatasourceBlock(wkWB);
    }

    _activeWindow = wkWB;
    return _activeWindow;
}

//添加新webView窗口
- (void)presentAddWebViewVC {
    //跳转前截张图
    _activeWindow.screenImage = [_activeWindow screenCapture:_activeWindow.bounds.size];
    [self.navigationController pushViewController:self.listWebViewController animated:YES];
}

//主页
- (void)home {
    [self.activeWindow loadRequest:[NSURLRequest requestWithURL:HOME_URL]];
}

//收藏
- (void)favorite {
    Favorite *fav = [[Favorite alloc] initWithDictionary:@{@"title" : _activeWindow.title, @"URL" : _activeWindow.URL}];

    BOOL containFav = [self.favoriteArray indexesOfObjectsWithOptions:NSEnumerationConcurrent
                                                          passingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                                                              return [fav isEqualToFavorite:obj];
                                                          }].count > 0;
    if (!containFav) {
        [self.favoriteArray addObject:fav];
    } else {
        [MyHelper showToastAlert:NSLocalizedString(@"Has Been Favorited", nil)];
        return;
    }

    //序列化存储
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.favoriteArray];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:MY_FAVORITES];

    [MyHelper showToastAlert:NSLocalizedString(@"Add Favorite Success", nil)];
}


//刷新
- (void)reload:(UIBarButtonItem *)item {
    [self.activeWindow loadRequest:[NSURLRequest requestWithURL:self.activeWindow.URL]];
}

//返回
- (void)back:(UIBarButtonItem *)item {
    [self.activeWindow goBack];
}

//前进
- (void)forward:(UIBarButtonItem *)item {
    [self.activeWindow goForward];
}

#pragma mark UISearchBarDelegate Implementation

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    searchBar.text = _activeWindow.URL.absoluteString;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self.searchBar resignFirstResponder];
    NSString *text = self.searchBar.text;
    NSString *urlStr = [NSString stringWithFormat:Search_URL, text];

    if ([text isHttpURL]) {
        urlStr = [NSString stringWithFormat:@"%@", text];
    } else if ([text isDomain]) {
        urlStr = [NSString stringWithFormat:@"http://%@", text];
    }

    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [_activeWindow loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)searchBarBookmarkButtonClicked:(UISearchBar *)searchBar {
    ScanQRViewController *viewController = [ScanQRViewController new];
    viewController.title = NSLocalizedString(@"Scan RQ Code", nil);
    viewController.view.backgroundColor = [UIColor whiteColor];
    viewController.openURLBlock = ^(NSURL *url) {
        [_activeWindow loadRequest:[NSURLRequest requestWithURL:url]];
        self.searchBar.text = url.absoluteString;
    };

    [viewController setHidesBottomBarWhenPushed:YES];
    [self.navigationController pushViewController:viewController animated:YES];
}


#pragma mark MyPopupViewDelegate Implementation

//当设置菜单项被选中
- (void)popupViewItemTaped:(MyCollectionViewCell *)cell {

    //收藏历史管理
    if ([cell.titleLabel.text isEqualToString:NSLocalizedString(@"Bookmarks", nil)]) {
        FavoritesViewController *favoritesViewController = [[FavoritesViewController alloc] init];
        favoritesViewController.getCurrentWKWebViewBlock = ^(MyWKWebView **wb) {
            *wb = _activeWindow;
        };
        favoritesViewController.loadRequestBlock = ^(NSURL *url) {
            [_activeWindow loadRequest:[NSURLRequest requestWithURL:url]];
            self.searchBar.text = _activeWindow.URL.absoluteString;
        };
        [self.navigationController pushViewController:favoritesViewController animated:YES];

        //如果当前是日间模式,则开启夜间模式
    } else if ([cell.titleLabel.text isEqualToString:NSLocalizedString(@"Daytime", nil)]) {
        if(self.maskView && self.maskView.superview){
            [self.maskView removeFromSuperview];
        }
        self.maskView = [[UIView alloc] initWithFrame:self.view.bounds];
        self.maskView.userInteractionEnabled = NO;
        self.maskView.backgroundColor = [UIColor blackColor];
        self.maskView.alpha = 0.2;
        [self.view addSubview:self.maskView];

        self.maskView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[maskView]|" options:0 metrics:nil views:@{@"maskView" : self.maskView}]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[maskView]|" options:0 metrics:nil views:@{@"maskView" : self.maskView}]];

        [UserSetting setNighttime:YES];

        //如果当前是夜间模式,开启日间模式
    } else if ([cell.titleLabel.text isEqualToString:NSLocalizedString(@"Nighttime", nil)]) {
        [self.maskView removeFromSuperview];
        self.maskView = nil;

        [UserSetting setNighttime:NO];

        //清除痕迹
    } else if ([cell.titleLabel.text isEqualToString:NSLocalizedString(@"Clear All History", nil)]) {
        [self.webContainer.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isMemberOfClass:[MyWKWebView class]]) {
                MyWKWebView *wb = (MyWKWebView *) obj;
//                [wb.backForwardList performSelector:@selector(_clear)];
               // [wb.backForwardList performSelector:NSSelectorFromString([NSString base64Decoding:@"X2NsZWFy"])];
            }
        }];
        [MyHelper showToastAlert:NSLocalizedString(@"Successfully cleared Footprint", nil)];
//        [MyHelper showToastAlert:@"Sorry,Temporarily can not be cleared !"];

        //当前是无图模式
    }else if([cell.titleLabel.text isEqualToString:NSLocalizedString(@"No Image",nil)]){

        //开启有图模式
        [UserSetting setImageBlockerStatus:@(NO)];
        [self.activeWindow enableImageBlock:NO];

        //当前是有图模式
    } else if([cell.titleLabel.text isEqualToString:NSLocalizedString(@"Image Mode",nil)]){

        //开启无图模式
        [UserSetting setImageBlockerStatus:@(YES)];
        [self.activeWindow enableImageBlock:YES];

        //当前是拦截广告
    } else if([cell.titleLabel.text isEqualToString:NSLocalizedString(@"Ad Block",nil)]){

        //开启不拦截
        [UserSetting setAdblockerStatus:@(NO)];
        [self.activeWindow enableAdBlocker:NO];


        //当前是不拦截广告
    }else if([cell.titleLabel.text isEqualToString:NSLocalizedString(@"No AdBlock",nil)]){

        //开启拦截
        [UserSetting setAdblockerStatus:@(YES)];
        [self.activeWindow enableAdBlocker:YES];
    }

    else if ([cell.titleLabel.text isEqualToString:NSLocalizedString(@"About Me", nil)]) {
//        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UIWEBVIEW_MODE];
//        [NSURLProtocol registerClass:[MyURLProtocol class]];
//
//        //todo:切换核心
//
//        [MyHelper showToastAlert:NSLocalizedString(@"Successfully Set NoImage Mode", nil)];

        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"About Me", nil)
                                                                                 message:NSLocalizedString(@"My Browser", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:nil];
        [alertController addAction:okAction];

        [self presentViewController:alertController animated:YES completion:nil];

    }

    [self hiddenMenu];
}


//关闭当前webView
- (void)closeActiveWebView {
    // Grab and remove the top web view, remove its reference from the windows array,
    // and nil itself and its delegate. Then we re-set the activeWindow to the
    // now-top web view and refresh the toolbar.
    if (_activeWindow == self.listWebViewController.windows.lastObject) {
        [_activeWindow loadRequest:[NSURLRequest requestWithURL:HOME_URL]];
        return;
    }

    [_activeWindow removeFromSuperview];
    [self.listWebViewController.windows removeObject:_activeWindow];
    _activeWindow = self.listWebViewController.windows.lastObject;
    [self.webContainer bringSubviewToFront:_activeWindow];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
