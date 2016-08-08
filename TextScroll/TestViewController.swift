//
//  ViewController.swift
//  TextScroll
//
//  Created by Michelle Feng on 7/7/16.
//  Copyright © 2016 cssummer16. All rights reserved.
//

import UIKit
import CoreMotion
import QuartzCore
import GPUImage

class TestViewController: UIViewController {
    
    @IBOutlet weak var blurScrollView: UIScrollView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var controlSwitch: UISwitch!
    @IBOutlet weak var debugLabel: UILabel!
    
    //Text settings
    let maxSize = CGSizeMake(99999, 99999) //max size of the scrollview
    var fontSize: CGFloat = 100
    var fontName = "Courier"
    var font: UIFont!
    
    //Tilt configuration settings
    var switchIsOn: Bool! //Gotten from Instructions V.C.
    var debugMode = false //show some helpful stats for debugging the scrollview.
    var tiltMapping = 0 //way that scrolling will react to tilt. 1: linear 0: impatient developer mode
    var finishedTutorial = false //Skips the acclimation test if tutorial was completed
    
    //Blur settings
    var textWindow: CGFloat = 5 //determine how many characters to appear sharp on the center screen
    let blurAmount: CGFloat = 10 //set how blurry the blurred text on right/left side should be
    var blurFilterSize: CGFloat = 0 //blurFilterSize

    //Variables to set specific boundaries of each part of the textscroll
    var label: UILabel! //holds the text
    var blurView: UIImageView! //blur mask over the clear, moving text
    var frame: CGRect! //bounds for the text label
    let screenRect: CGRect = UIScreen.mainScreen().bounds
    
    @IBOutlet weak var svWidth: NSLayoutConstraint!
    @IBOutlet weak var svHeight: NSLayoutConstraint!
    
    //Start on iteration at -1 for acclimation text
    var text: String!
    var iteration:Int=(-1)
    var totalIterations:Int = 2 //set how many text samples to give before submission

    //Different types of text
    let textTypes:Array<String>=["Semantics","Syntactic","Lexical"]
    var textVersion:String!
    
    //Randomly picks which version, A or B you will start with
    var versionNumber:Int=Int(arc4random_uniform(2))
    let textVersions:Array<String>=["A","B"]
    
    //The number of texts per text type
    let numberOfTexts:Int=4
    var nextText:String!
    var textType:String!
    
    var doneWithText = false
    
    var textDictionary:Dictionary<String,String>!
    var masterDataDictionary = Dictionary<String, [(Double, Double)]>()
    var data: [(Double, Double)] = []
    
    //Accelerometer setup
    var motionManager: CMMotionManager!
    var queue: NSOperationQueue!
    var accel: Double!
    var i0: Double! = 0.0 //holds the previous i
    
    //Animation/stopwatch
    var anim: CAKeyframeAnimation = CAKeyframeAnimation()
    var stopWatch = StopWatch()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        font = UIFont(name: fontName, size: fontSize)
        
        nextButton.hidden = true
        nextButton.layer.cornerRadius = 10
        nextButton.clipsToBounds = true
        debugLabel.hidden = true
        
        if !switchIsOn{
            controlSwitch.setOn(false, animated: false)
        }
        
        //Preliminary text setup so that dimensions can be specified for the first runthrough
        text = getNextText()
        
        let strSize = (text as NSString).boundingRectWithSize(maxSize, options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName : font], context: nil)
        
        //Set up the Scroll View
        let screenWidth = screenRect.size.width
        svWidth.constant = screenWidth
        svHeight.constant = strSize.height
        scrollView.contentSize = CGSizeMake(strSize.width, strSize.height)
        scrollView.userInteractionEnabled = false
        scrollView.layer.cornerRadius = 20
        scrollView.clipsToBounds = true
        
        blurScrollView.layer.cornerRadius = 20
        blurScrollView.clipsToBounds = true
        blurScrollView.backgroundColor = UIColor.whiteColor()
        
        //Create the text inside the ScrollView
        setupText(textWindow, blurAmount: blurAmount)
        
        //Set up moving label and update screen with the dimensions specified above
        setupMotion()
    }
    
    func setupMotion(){
        /**
         Set up motion aspects of the label as well as multithreading
         */
        
        motionManager=CMMotionManager()
        queue=NSOperationQueue()

        if motionManager.accelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.02
            motionManager.startAccelerometerUpdatesToQueue(self.queue, withHandler: {accelerometerData, error in
                guard let accelerometerData = accelerometerData else {return}
                
                self.accel = accelerometerData.acceleration.y
                
                //multithreading required for items that don't automatically refresh on the screen after
                //they've been changed
                dispatch_async(dispatch_get_main_queue()) {
                    
                    //Control switch functionality
                    if self.controlSwitch.on {
                        self.accel = accelerometerData.acceleration.y
                    } else {
                        self.accel = -accelerometerData.acceleration.y
                    }
                    
                    //Calculate movement based off accel
                    let characters = Double(self.text.length)
                    var i: Double!
                    switch (self.tiltMapping) {
                    case (1):
                        //linear: speed = accel
                        i = self.accel/characters
                        if abs(i) < 0.00025 {
                            i = 0.0
                        }
                    case (2):
                        //constant acceleration - lets level ipad maintain a constant speed
                        i = self.i0 + 0.01/characters * self.accel
                        if abs(i) > 0.5/characters { //sets max speed
                            i = copysign(0.5/characters, i)
                        }
                        if self.label.layer.timeOffset == 0 || self.label.layer.timeOffset == 1.0{
                            i = 0.01/characters * self.accel //resets speed if the end is reached
                        }
                        self.i0 = i
                    case (3):
                        //speed = accel^3
                        i = 10/characters * pow(self.accel, 3)
                        if abs(i) > 0.5/characters {
                            i = copysign(0.5/characters, i)
                        }
                        self.i0 = i
                    default:
                        i = self.accel/10
                    }
                    
                    if self.label.layer.timeOffset + i >= 0 && self.label.layer.timeOffset + i <= 1.0{
                        self.label.layer.timeOffset += i
                        self.blurView.layer.timeOffset += i
                    }
                    else if self.label.layer.timeOffset + i >= 1.0{
                        self.label.layer.timeOffset = 1.0
                        self.blurView.layer.timeOffset = 1.0
                        //Make the 'next' button appear, but only do this once
                        if !self.doneWithText {
                            self.nextButton.hidden = false
                            self.nextButton.alpha = 0
                            UIView.animateWithDuration(0.1, animations: {
                                self.nextButton.center = CGPointMake(self.nextButton.center.x, self.nextButton.center.y - 20)
                                self.nextButton.alpha = 1.0
                            })
                        }
                        self.doneWithText = true
                    }
                    //Collect data
                    let timeStamp = self.stopWatch.roundTime(4)
                    let progress = i!
                    let dataPoint = (timeStamp, progress)
                    self.data.append(dataPoint)
                    
                    //Debug Mode
                    if self.debugMode{
                        self.debugLabel.hidden = false
                        let time = self.stopWatch.timeIntervalToString()!
                        let accel = round(1000 * self.accel)/1000
                        let progress = round(100 * self.label.layer.timeOffset)
                        self.debugLabel.text = "Time: \(time)  Accel: \(accel)  Progress: \(progress)%"
                    }
                }
            })
        }
    }
    
    func setupText(textWindow: CGFloat, blurAmount: CGFloat){
        /**
        Handles updating the new text and animation
        Updated text, scrollView/blurView dimensions must be established before calling this function.
        */
        
        if label != nil {
            text = getNextText()
            label.removeFromSuperview()
            blurView.removeFromSuperview()
        }
            
        else if iteration >= 1{
            controlSwitch.userInteractionEnabled = false
            controlSwitch.alpha = 0.2
            
            masterDataDictionary["'"+nextText+textType+"'"] = data
            data = [] //clear data after entry is recorded
        }
        
        //Prepare the button to appear as 'finish' at the end of the passage
        if iteration == totalIterations{
            nextButton.setTitle(" Finish ", forState: UIControlState.Normal)
        }
        
        //Prep for fade-in animation
        scrollView.alpha = 0.0
        blurScrollView.alpha = 0.0
        
        let textFontAttributes = [
            NSFontAttributeName : font,
            NSForegroundColorAttributeName: UIColor.blackColor()
        ]
        let strSize = (text as NSString).boundingRectWithSize(maxSize, options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: textFontAttributes, context: nil)
        frame = CGRectMake(0, 0, strSize.width + screenRect.size.width, svHeight.constant) //allot enough width to let text start offscreen
        label = UILabel(frame: frame)
        label.text = text
        label.font = font
        label.textAlignment = .Right
        label.backgroundColor = UIColor.clearColor()
        
        applyGradientMask(textWindow)
        
        //Set up the animation
        anim.keyPath = "position.x"
        //set start/end position. End position calculated so that text doesn't scroll off screen but scrolls far enough
        //to let the last bit of text go past the blur filter
        anim.values = [0, -frame.size.width + scrollView.frame.size.width - blurFilterSize]
        anim.keyTimes = [0, 1]
        anim.duration = 1.0
        anim.removedOnCompletion = false
        anim.additive = true
        
        label.layer.addAnimation(anim, forKey: "move")
        label.layer.speed = 0.0 //so it doesn't move by itself
        label.layer.timeOffset = 0.0
        blurView.layer.addAnimation(anim, forKey: "move")
        blurView.layer.speed = 0.0
        blurView.layer.timeOffset = 0.0
        
        //Let updated view appear
        UIView.animateWithDuration(0.3, animations: {
            self.scrollView.alpha = 1.0
            self.blurScrollView.alpha = 1.0
        })
        stopWatch.reset()
        stopWatch.start()
        
        nextButton.hidden = true
        doneWithText = false
    }
    
    func getNextText() -> String {
        //Determines which text to use next and returns the string of that text
        if iteration==(-1) {
            textType="Acclimation"
        }
        else {
            textType=textTypes[iteration/numberOfTexts]
        }
        let path=NSBundle.mainBundle().pathForResource(textType,ofType:"plist")
        let myDict=NSDictionary(contentsOfFile: path!)
        textDictionary=myDict as! Dictionary<String,String>
        //Switch version every text
        versionNumber=(versionNumber+1)%2
        textVersion=textVersions[versionNumber]
        
        if iteration==(-1) {nextText="1A"}
        else {
            nextText=String((iteration%numberOfTexts)+1)+textVersion
        }
        iteration += 1
        
        return textDictionary[nextText]!
    }

    func applyGradientMask(textWindow: CGFloat) {
        /**
         Sets up the left/right blur effect and adds text to the scrolling view(s)
         Updated text, scrollView/blurView dimensions must be established before calling this function.
         */
        
        //get text sample to calculate the window size. *1.5+round up seems to get about the right size...
        let stringSample = NSString(string: text).substringToIndex(Int(ceil(textWindow * 1.5)))
        let windowSize: CGSize = stringSample.sizeWithAttributes([NSFontAttributeName: UIFont.systemFontOfSize(fontSize)])
        //size of blur filter in pixels for other functions to read
        blurFilterSize = (svWidth.constant - windowSize.width)/2
        //blurFilterSize (%). calculates the length of the left/right filter in a percentage based way for gradient.locations to understand.
        let bFS = (1.0-(windowSize.width/svWidth.constant))/2
        //If blur not needed, just add the clear text to the scroll view
        if bFS <= 0 || blurAmount <= 0{
            scrollView.addSubview(label)
            return
        }
        
        //Set up blurView
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 0)
        let maskAttributes: [String: AnyObject] = [
            NSFontAttributeName: font!
        ]
        
        //Generate a rectangle of the size of the text strip
        //to draw the text in at coordinates (width,0) to let the blurred text start offscreen
        let textRect = CGRectMake(svWidth.constant, 0, frame.width, frame.height)
        text.drawInRect(textRect, withAttributes: maskAttributes)
        
        let img = UIGraphicsGetImageFromCurrentImageContext()
        
        let blurFilter = GPUImageGaussianBlurFilter()
        blurFilter.blurRadiusInPixels = blurAmount
        
        let outputImage = blurFilter.imageByFilteringImage(img)
        print("SIZE")
        print(outputImage.size)
        blurView = UIImageView(frame: CGRectMake(0, 0, frame.width, frame.height))
        blurView.image = outputImage
        
        //Create gradient
        let clear = UIColor.clearColor().CGColor
        let white = UIColor.whiteColor().CGColor
        blurView.backgroundColor = UIColor.whiteColor()
        
        let gradient = CAGradientLayer()
        gradient.bounds = scrollView.layer.bounds
        gradient.colors = [clear, clear, white, white, clear, clear]
        gradient.bounds = scrollView.layer.bounds
        gradient.frame = scrollView.superview?.bounds ?? CGRectNull
        
        gradient.startPoint = CGPointMake(0.0, 0.5)
        gradient.endPoint = CGPointMake(1.0, 0.5)
        gradient.locations = [0.0, bFS*0.9, bFS, (1-bFS)*0.9, (1-bFS), 1.0]
        
        scrollView.layer.mask = gradient
        
        //Top
        //scrollView with gradient mask
        //label in scrollView
        //blurScrollView (blurred text)
        //Bottom
        blurScrollView.addSubview(blurView)
        scrollView.addSubview(label)
        scrollView.superview?.bringSubviewToFront(scrollView)
    }
    
    @IBAction func nextButtonPressed(sender: AnyObject) {
        if iteration == totalIterations{
            performSegueWithIdentifier("toMetricsViewController", sender: sender)
        }
        else{
            setupText(textWindow, blurAmount: blurAmount)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        //Passes data to MVC
        if segue.identifier=="toMetricsViewController" {
            let mvc = segue.destinationViewController as! MetricsViewController
            masterDataDictionary["'"+nextText+textType+"'"] = data
            data = [] //clear data after entry is recorded
            mvc.masterData = self.masterDataDictionary
        }
    }
}

