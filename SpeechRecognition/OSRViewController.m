//
//  ViewController.m
//  SpeechRecognition
//
//  Created by Kouhei Suzuki on 2015/05/02.
//  Copyright (c) 2015年 kouheiszk. All rights reserved.
//

#import "OSRViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <OpenEars/OELanguageModelGenerator.h>
#import <OpenEars/OEAcousticModel.h>
#import <OpenEars/OEPocketsphinxController.h>
#import <OpenEars/OEEventsObserver.h>

static NSString *const kModelFilesName = @"modles";
static NSString *const kModelName = @"AcousticModelEnglish";

@interface OSRViewController () <OEEventsObserverDelegate>

@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet UITextView *inputTextView;
@property (weak, nonatomic) IBOutlet UIButton *createModelButton;
@property (weak, nonatomic) IBOutlet UILabel *resultLabel;

@property (nonatomic) OEEventsObserver *openEarsEventsObserver;

@end

@implementation OSRViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _openEarsEventsObserver = [[OEEventsObserver alloc] init];
        [_openEarsEventsObserver setDelegate:self];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    [self requestRecordPermission];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Private methods

- (void)requestRecordPermission
{
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (granted) {

        }
        else {
            _messageLabel.text = NSLocalizedString(@"Please grant permission", @"許可してね");
        }
    }];
}

- (void)createModelWithSentence:(NSString *)sentence
                     completion:(void(^)(NSString *languageModelPath, NSString *dicPath, NSString *modelPath, NSError *error))completions
{
    OELanguageModelGenerator *languageModelGenerator = [[OELanguageModelGenerator alloc] init];
    NSString *modelPath = [OEAcousticModel pathToModel:kModelName];

    NSArray *words = ({
        NSArray *words = [sentence componentsSeparatedByString:@" "];
        NSMutableArray *uppercaseWords = [NSMutableArray array];
        [words enumerateObjectsUsingBlock:^(NSString *word, NSUInteger idx, BOOL *stop) {
            [uppercaseWords addObject:[word uppercaseString]];
        }];
        [uppercaseWords copy];
    });
    NSError *error = [languageModelGenerator generateLanguageModelFromArray:words
                                                             withFilesNamed:kModelFilesName
                                                     forAcousticModelAtPath:modelPath];

    NSString *languageModelPath = nil;
    NSString *dicPath = nil;

    if (error) {
        if (completions) completions(nil, nil, nil, error);
    }
    else {
        languageModelPath = [languageModelGenerator pathToSuccessfullyGeneratedLanguageModelWithRequestedName:kModelFilesName];
        dicPath = [languageModelGenerator pathToSuccessfullyGeneratedDictionaryWithRequestedName:kModelFilesName];
        if (completions) completions(languageModelPath, dicPath, modelPath, nil);
    }
}

- (void)startListeningWithSentence:(NSString *)sentence
{
    [self createModelWithSentence:sentence completion:^(NSString *languageModelPath, NSString *dicPath, NSString *modelPath, NSError *error) {
        if (!languageModelPath || !dicPath || !modelPath || error) {
            NSLog(@"Failed to create model : %@", error);
            _messageLabel.text = [error localizedDescription];
            return;
        }

        [[OEPocketsphinxController sharedInstance] setActive:YES error:nil];
        [[OEPocketsphinxController sharedInstance] startListeningWithLanguageModelAtPath:languageModelPath
                                                                        dictionaryAtPath:dicPath
                                                                     acousticModelAtPath:modelPath
                                                                     languageModelIsJSGF:NO];
    }];
}

#pragma mark - OEEventsObserverDelegate

- (void)pocketsphinxDidReceiveHypothesis:(NSString *)hypothesis
                        recognitionScore:(NSString *)recognitionScore
                             utteranceID:(NSString *)utteranceID
{
    _messageLabel.text = NSLocalizedString(@"Finished", @"終わり");
    NSLog(@"The received hypothesis is %@ with a score of %@ and an ID of %@", hypothesis, recognitionScore, utteranceID);
    _resultLabel.text = hypothesis;
    [[OEPocketsphinxController sharedInstance] setActive:NO error:NULL];
    [[OEPocketsphinxController sharedInstance] stopListening];
}

- (void)pocketsphinxDidStartListening
{

    _messageLabel.text = NSLocalizedString(@"Now listening", nil);
    NSLog(@"Pocketsphinx is now listening.");
}

- (void)pocketsphinxDidDetectSpeech
{
    NSLog(@"Pocketsphinx has detected speech.");
}

- (void)pocketsphinxDidDetectFinishedSpeech
{
    NSLog(@"Pocketsphinx has detected a period of silence, concluding an utterance.");
}

- (void)pocketsphinxDidStopListening
{
    _messageLabel.text = NSLocalizedString(@"Stopped listening", nil);
    NSLog(@"Pocketsphinx has stopped listening.");
}

- (void)pocketsphinxDidSuspendRecognition
{
    NSLog(@"Pocketsphinx has suspended recognition.");
}

- (void)pocketsphinxDidResumeRecognition
{
    NSLog(@"Pocketsphinx has resumed recognition.");
}

- (void)pocketsphinxDidChangeLanguageModelToFile:(NSString *)newLanguageModelPathAsString
                                   andDictionary:(NSString *)newDictionaryPathAsString
{
    NSLog(@"Pocketsphinx is now using the following language model: \n%@ and the following dictionary: %@",newLanguageModelPathAsString,newDictionaryPathAsString);
}

- (void)pocketSphinxContinuousSetupDidFailWithReason:(NSString *)reasonForFailure
{
    NSLog(@"Listening setup wasn't successful and returned the failure reason: %@", reasonForFailure);
}

- (void)pocketSphinxContinuousTeardownDidFailWithReason:(NSString *)reasonForFailure
{
    NSLog(@"Listening teardown wasn't successful and returned the failure reason: %@", reasonForFailure);
}

- (void)testRecognitionCompleted
{
    NSLog(@"A test file that was submitted for recognition is now complete.");
}

#pragma mark - IBActions

- (IBAction)createModelButtonTapped:(id)sender
{
    NSString *sentence = [_inputTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (sentence.length > 0) {
        [self startListeningWithSentence:sentence];
    }
    else {
        _messageLabel.text = NSLocalizedString(@"Please input sentence", @"入力してね");
    }
}


@end
