//
//  IssueViewController.m
//  Baker
//
//  ==========================================================================================
//
//  Copyright (c) 2010-2012, Davide Casali, Marco Colombo, Alessandro Morandi
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are
//  permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this list of
//  conditions and the following disclaimer.
//  Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials
//  provided with the distribution.
//  Neither the name of the Baker Framework nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission.
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
//  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
//  SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "IssueViewController.h"

#import "SSZipArchive.h"

#define REMOTE_TEXT @"Download"
#define DOWNLOADING_TEXT @"Downloading..."
#define DOWNLOADED_TEXT @"View"
#define OPENING_TEXT @"Loading..."
#define ARCHIVE_TEXT @"Archive"

@interface IssueViewController ()

@end

@implementation IssueViewController

@synthesize issue;
@synthesize button;
@synthesize archiveButton;
@synthesize progress;
@synthesize spinner;

- (id)initWithBakerIssue:(BakerIssue *)bakerIssue {
    self = [super init];
    
    if (self) {
        self.issue = bakerIssue;
    }
    
    return self;
}

- (void)loadView {
    [super loadView];
    
    self.view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 384, 192)] autorelease];
    self.view.backgroundColor = [UIColor clearColor];
    
    UIActivityIndicatorView *coverLoadingSpinner = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
    coverLoadingSpinner.color = [UIColor whiteColor];
    coverLoadingSpinner.backgroundColor = [UIColor clearColor];
    coverLoadingSpinner.center = CGPointMake(71, 96);
    [self.view addSubview:coverLoadingSpinner];
    [coverLoadingSpinner startAnimating];
    
    UILabel *title = [[[UILabel alloc]initWithFrame:CGRectMake(142, 21, 221, 25)] autorelease];
    title.text = self.issue.title;
    [title setFont:[UIFont fontWithName:@"Arial-BoldMT" size:16]];
    title.textColor = [UIColor whiteColor];
    title.backgroundColor = [UIColor clearColor];
    [self.view addSubview:title];
    
    self.progress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.progress.frame = CGRectMake(142, 50, 221, 30);
    [self.view addSubview:self.progress];
    
    self.spinner = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite] autorelease];
    self.spinner.center = self.progress.center;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    
    self.button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.button.frame = CGRectMake(142, 85, 221, 30);
    [self.button addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.button];
    
    self.archiveButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.archiveButton.frame = CGRectMake(142, 120, 221, 30);
    [self.archiveButton setTitle:ARCHIVE_TEXT forState:UIControlStateNormal];
    [self.archiveButton addTarget:self action:@selector(archiveButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.archiveButton];
    
    [self.issue getCover:^(UIImage *img) {
        UIImageView *thumb = [[[UIImageView alloc] initWithImage:img] autorelease];
        thumb.frame = CGRectMake(21, 21, 100, 150);
        [self.view addSubview:thumb];
    }];
}

- (void)refresh {
    [self refresh:[self.issue getStatus]];
}
- (void)refresh:(NSString *)status {
    NSLog(@"refreshing %@ with status %@", self.issue.ID, status);
    if (status == @"remote") {
        [self.button setTitle:REMOTE_TEXT forState:UIControlStateNormal];
        self.progress.hidden = YES;
        self.button.enabled = YES;
        self.archiveButton.hidden = YES;
        [self.spinner stopAnimating];
    } else if (status == @"downloading") {
        [self.progress setProgress:0.0 animated:NO];
        [self.button setTitle:DOWNLOADING_TEXT forState:UIControlStateNormal];
        self.progress.hidden = NO;
        self.button.enabled = NO;
        self.archiveButton.hidden = YES;
    } else if (status == @"downloaded") {
        [self.button setTitle:DOWNLOADED_TEXT forState:UIControlStateNormal];
        self.progress.hidden = YES;
        self.button.enabled = YES;
        self.archiveButton.hidden = NO;
        self.archiveButton.enabled = YES;
        [self.spinner stopAnimating];
    } else if (status == @"bundled") {
        [self.button setTitle:DOWNLOADED_TEXT forState:UIControlStateNormal];
        self.progress.hidden = YES;
        self.button.enabled = YES;
        self.archiveButton.hidden = YES;
        [self.spinner stopAnimating];
    } else if (status == @"opening") {
        [self.button setTitle:OPENING_TEXT forState:UIControlStateNormal];
        self.button.enabled = NO;
        self.archiveButton.enabled = NO;
        [self.spinner startAnimating];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)buttonPressed:(UIButton *)sender {
    NSString *status = [self.issue getStatus];
    if (status == @"remote") {
        [self download];
    } else if (status == @"downloaded" || status == @"bundled") {
        [self read];
    } else if (status == @"downloading") {
        // TODO: assuming it is supported by NewsstandKit, implement a "Cancel" operation
    }
}

#ifdef BAKER_NEWSSTAND
- (void)archiveButtonPressed:(UIButton *)sender {
    NKLibrary *nkLib = [NKLibrary sharedLibrary];
    NKIssue *nkIssue = [nkLib issueWithName:self.issue.ID];
    NSString *name = nkIssue.name;
    NSDate *date = nkIssue.date;
    
    [nkLib removeIssue:nkIssue];
    nkIssue = [nkLib addIssueWithName:name date:date];
    self.issue.path = [[nkIssue contentURL] path];
    
    [self refresh];
}
#endif

- (void)download {
    [self refresh:@"downloading"];
    [self.issue downloadWithDelegate:self];
}
- (void)read {
    [self refresh:@"opening"];
    dispatch_async(dispatch_get_main_queue(),^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"read_issue_request" object:self];
    });
}

#ifdef BAKER_NEWSSTAND
#pragma mark - Newsstand download

- (void)connection:(NSURLConnection *)connection didWriteData:(long long)bytesWritten totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long)expectedTotalBytes {
    
    [self.progress setProgress:((float)totalBytesWritten/(float)expectedTotalBytes) animated:YES];
}
- (void)connectionDidFinishDownloading:(NSURLConnection *)connection destinationURL:(NSURL *)destinationURL {
    NSLog(@"CONNECTION DID FINISH DOWNLOADING %@", destinationURL);
    
    NKAssetDownload *dnl = connection.newsstandAssetDownload;
    NKIssue *nkIssue = dnl.issue;
    NSString *destinationPath = [[nkIssue contentURL] path];
    
    NSLog(@"File is being unzipped to %@", destinationPath);
    [SSZipArchive unzipFileAtPath:[destinationURL path] toDestination:destinationPath];
    
    [self refresh];
    
    // TODO: update Newsstand icon and add badge
}
- (void)connectionDidResumeDownloading:(NSURLConnection *)connection totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long)expectedTotalBytes {
    NSLog(@"CONNECTION DID RESUME DOWNLOADING %lld %lld", totalBytesWritten, expectedTotalBytes);
    
    [self.progress setProgress:((float)totalBytesWritten/(float)expectedTotalBytes) animated:YES];
}
#endif

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [issue release];
    [button release];
    [archiveButton release];
    [progress release];
    [spinner release];
    
    [super dealloc];
}

@end