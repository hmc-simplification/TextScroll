//
//  TutorialViewController.swift
//  TextScroll
//
//  Created by cssummer16 on 7/13/16.
//  Copyright © 2016 cssummer16. All rights reserved.
//

import UIKit
import CoreMotion
import QuartzCore
import GPUImage
import AVFoundation

class TutorialViewController: UIViewController {
    /**
     Guides the user through a thorough tutorial on how to use the tilt-to-scroll-text mechanism.
     */
    
    @IBOutlet weak var blurScrollView: UIScrollView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var controlSwitch: UISwitch!
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var switchLabel: UILabel!
    
    let maxSize = CGSizeMake(99999, 99999) //max size of the scrollview
    var fontSize: CGFloat = 100
    var fontName = "Courier"
    var font: UIFont!
    
    var finishedTutorial = false
    
    //Tilt configuration settings
    var switchIsOn = false //Gotten from Instructions V.C.
    var tiltMapping = 1 //way that scrolling will react to tilt. 1: linear^3 2: constant accel 3: linear 0: impatient developer mode
    var nextStep = "showLabel" //Helps tutorial(next button, accelerometer) determine which transition to execute
    
    //Blur settings
    var textWindow: CGFloat = 5 //determine how many characters to appear sharp on the center screen
    let blurAmount: CGFloat = 10 //set how blurry the blurred text on right/left side should be
    var blurFilterSize: CGFloat = 0 //blurFilterSize
    
    //Variables to set specific boundaries of each part of the textscroll
    var label: UILabel! //holds the text
    var blurView: UIImageView! //blurred text
    var frame: CGRect! //bounds for the text label
    let screenRect: CGRect = UIScreen.mainScreen().bounds
    
    //scroll view width/height
    @IBOutlet weak var svWidth: NSLayoutConstraint!
    @IBOutlet weak var svHeight: NSLayoutConstraint!
    
    //Start on iteration at -1 for acclimation text
    var text: String!
    var iteration:Int=(-1)
    var totalIterations:Int = 1 //set how many text samples to give before submission
    
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
    
    //Accelerometer setup
    var motionManager: CMMotionManager!
    var queue: NSOperationQueue!
    var accel: Double!
    var i0: Double! = 0.0 //holds the previous i
    
    //Animation
    var anim: CAKeyframeAnimation = CAKeyframeAnimation()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        font = UIFont(name: fontName, size: fontSize)
        
        //View setup
        nextButton.layer.cornerRadius = 10
        nextButton.clipsToBounds = true
        
        scrollView.alpha = 0.0
        blurScrollView.alpha = 0.0
        switchLabel.hidden = true
        controlSwitch.hidden = true
        
        if !switchIsOn{
            controlSwitch.setOn(false, animated: false)
        }
        
        //Create the text inside the ScrollView
        let screenWidth = screenRect.size.width
        
        text = getNextText()
        let strSize = (text as NSString).boundingRectWithSize(maxSize, options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName : font!], context: nil)
        
        //Set up the Scroll View
        //blurScrollView (holding blurView, the blurred text) underneath scrollView (holding label, the sharp text)
        //must have identical dimensions and are perfectly laid over each other with autolayout + hardcode
        svWidth.constant = screenWidth
        svHeight.constant = strSize.height
        scrollView.contentSize = CGSizeMake(strSize.width, strSize.height)
        scrollView.userInteractionEnabled = false
        scrollView.layer.cornerRadius = 20
        scrollView.clipsToBounds = true
        scrollView.backgroundColor = UIColor.whiteColor()

        blurScrollView.layer.cornerRadius = 20
        blurScrollView.backgroundColor = UIColor.whiteColor()
 
    }
    
    //Set up motion aspects of the label as well as multithreading
    func setupMotion(){
        
        //Set up accelerometer
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
                        if self.label.layer.timeOffset == 0 || self.label.layer.timeOffset >= 0.99{
                            i = 0.03/characters * self.accel //resets speed if the end is reached for an easy turnaround
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
                        
                        //Determines when to transition to next tutorial step
                        if self.nextStep == "tiltRight" && self.label.layer.timeOffset >= 0.9 {
                            self.nextButton.hidden = false
                            if self.tiltMapping == 2{
                                self.updateInstructions("Tilt the device right to speed up the text ✓ \n Tilt the device left to slow down/scroll backwards \n Hold the device level once you are at a comfortable speed", fadeIn: 0.3)
                            } else {
                                self.updateInstructions("Tilt the device right to let the text scroll into view ✓ \n Tilt the device left to scroll backwards  ", fadeIn: 0.3)
                            }
                            self.nextStep = "tiltLeft"
                        }
                        else if self.nextStep == "tiltLeft" && self.label.layer.timeOffset <= 0.7{
                            if self.tiltMapping == 2{
                                self.updateInstructions("Tilt the device right to speed up the text ✓ \n Tilt the device left to slow down/scroll backwards ✓ \n Hold the device level when you are at a comfortable speed", fadeIn: 0.3)
                            } else {
                                self.updateInstructions("Tilt the device right to let the text scroll into view ✓ \n Tilt the device left to scroll backwards ✓", fadeIn: 0.3)
                            }
                            self.nextButton.hidden = false
                            UIView.animateWithDuration(0.3, delay:1.0, options: .CurveEaseInOut, animations: {
                                self.nextButton.center = CGPointMake(self.nextButton.center.x, self.nextButton.center.y - 20)
                                self.nextButton.alpha = 1.0
                                }, completion: nil)
                            self.nextStep = "showSwitch"
                        }
                        else if self.nextStep == "showSwitch" && self.controlSwitch.on {
                            self.scrollView.addSubview(self.label)
                            self.blurScrollView.addSubview(self.blurView)
                            self.controlSwitch.layer.removeAllAnimations()
                            self.updateInstructions("Tilt the device left to scroll forwards  ", fadeIn: 0.3)
                            UIView.animateWithDuration(0.3, animations: {
                                self.controlSwitch.alpha = 0.5
                            })
                            self.controlSwitch.userInteractionEnabled = false
                            self.nextStep = "reverseTiltRight"
                        }
                        else if self.nextStep == "reverseTiltRight" && self.label.layer.timeOffset >= 0.8 {
                            self.updateInstructions("Tilt the device left to scroll forwards ✓ \n Tilt the device right to scroll backwards  ", fadeIn: 0.3)
                            self.nextStep = "reverseTiltLeft"
                        }
                        else if self.nextStep == "reverseTiltLeft" && self.label.layer.timeOffset <= 0.6 {
                            self.updateInstructions("Tilt the device left to scroll forwards ✓ \n Tilt the device right to scroll backwards ✓", fadeIn: 0.3)
                            self.nextButton.hidden = false
                            UIView.animateWithDuration(0.3, delay:1.0, options: .CurveEaseInOut, animations: {
                                self.nextButton.center = CGPointMake(self.nextButton.center.x, self.nextButton.center.y - 20)
                                self.nextButton.alpha = 1.0
                                }, completion: nil)
                                self.nextStep = "freePlay"
                        }
                    }
                }
            })
        }
    }
    
    func setupText(textWindow: CGFloat, blurAmount: CGFloat){
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
        */
        
        //get text sample to calculate the window size. *1.4+round up seems to get about the right size...
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
        
        //Generate a rectangle of the size of the text strip (*1.1 is to give the blurred text some "bleed room")
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
        if nextStep == "showLabel" {
            setupText(textWindow, blurAmount: blurAmount)
            updateInstructions("This is where the text will appear.", fadeIn: 0.2)
            nextButton.setTitle(" Try it out ", forState: UIControlState.Normal)
            self.nextButton.hidden = false
            self.nextButton.alpha = 0
            self.nextButton.userInteractionEnabled = false
            UIView.animateWithDuration(0.3, delay:1.0, options: .CurveEaseInOut, animations: {
                self.nextButton.alpha = 1.0
                }, completion: {
                    (value:Bool) in
                    self.nextButton.userInteractionEnabled = true
            })
            nextStep = "tiltRight"
        }
        else if nextStep == "tiltRight" {
            setupMotion()
            if tiltMapping == 2{
                updateInstructions("Gently tilt the device right to increase the text's scroll speed \n Hold the iPad level once you are at a comfortable speed", fadeIn: 0.3)
                } else {
                    updateInstructions("Tilt the device right to let the text scroll into view", fadeIn: 0.2)
                }
            self.nextButton.hidden = true
            self.nextButton.alpha = 0
            nextButton.setTitle(" Next ", forState: UIControlState.Normal)
        }
        else if nextStep == "showSwitch" {
            updateInstructions("Great! Now try the reverse by tapping the switch on the lower right.", fadeIn: 0.2)
            self.nextButton.hidden = true
            self.nextButton.alpha = 0
            self.switchLabel.hidden = false
            self.switchLabel.alpha = 0
            self.controlSwitch.hidden = false
            self.switchLabel.alpha = 0
            label.removeFromSuperview()
            blurView.removeFromSuperview()
            self.label.layer.timeOffset = 0.0
            self.blurView.layer.timeOffset = 0.0
            self.nextButton.userInteractionEnabled = false
            UIView.animateWithDuration(0.3, delay:1.0, options: .CurveEaseInOut, animations: {
                self.switchLabel.alpha = 1.0
                self.controlSwitch.alpha = 1.0
                }, completion: {
                    (value:Bool) in
                    self.nextButton.userInteractionEnabled = true
            })
            let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
            pulseAnimation.duration = 1
            pulseAnimation.fromValue = 1
            pulseAnimation.toValue = 1.5
            pulseAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            pulseAnimation.autoreverses = true
            pulseAnimation.repeatCount = MAXFLOAT
            controlSwitch.layer.addAnimation(pulseAnimation, forKey: nil)
        }
        else if self.nextStep == "freePlay" {
            self.updateInstructions("Free play! \n Adjust the switch to the tilt configuration that’s most comfortable for you. \n You can still change this setting in the first passage after this tutorial.", fadeIn: 0.3)
            UIView.animateWithDuration(0.2, animations: {
                self.controlSwitch.alpha = 1.0
            })
            controlSwitch.userInteractionEnabled = true
            nextButton.hidden = false
            nextButton.setTitle(" Finish Tutorial ", forState: UIControlState.Normal)
            UIView.animateWithDuration(0.3, delay: 3.0, options: .CurveEaseInOut, animations: {
                self.nextButton.alpha = 1.0
                }, completion: nil)
            nextStep = "finish"
        }
        else if nextStep == "finish" {
            finishedTutorial = true
            performSegueWithIdentifier("toInstructionsViewController", sender: sender)
        }
    }
    
    
    func updateInstructions(text: String, fadeIn: Double){
        instructionsLabel.alpha = 0
        instructionsLabel.text = text
        UIView.animateWithDuration(fadeIn, animations: {
            self.instructionsLabel.alpha = 1.0
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        //Passes data to MVC
        if segue.identifier=="toInstructionsViewController" {
            let ivc = segue.destinationViewController as! InstructionsViewController
            ivc.controlSwitchIsOn = controlSwitch.on
            ivc.tiltMapping = tiltMapping
            ivc.finishedTutorial = finishedTutorial
            ivc.fontSize = fontSize
            ivc.fontName = fontName
            ivc.totalIterations = totalIterations
            ivc.textWindow = textWindow
            if finishedTutorial{
                ivc.iteration = 0
            }
        }
    }
}
