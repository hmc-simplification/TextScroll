//
//  IntroViewController.swift
//  TextScroll
//
//  Created by Michelle Feng on 7/11/16.
//  Copyright © 2016 cssummer16. All rights reserved.
//

import UIKit
import Firebase

class IntroViewController: UIViewController {
    /**
     Code for TextScroll's start screen.
     Rounds corners of the start button and fetches remote config variable values from Firebase.
    */
    
    @IBOutlet weak var startButton: UIButton!
    var remoteConfig:FIRRemoteConfig!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startButton.layer.cornerRadius = 10
        startButton.clipsToBounds = true
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        //Fetch remote config data from Firebase and sends info to Tutorial View Controller
        if segue.identifier=="toTutorialViewController" {
            let tvc = segue.destinationViewController as! TutorialViewController
            
            //Remote config setup
            self.remoteConfig = FIRRemoteConfig.remoteConfig()
            let remoteConfigSettings = FIRRemoteConfigSettings(developerModeEnabled: true)
            remoteConfig.configSettings = remoteConfigSettings!
            var defaultValues = NSDictionary()
            defaultValues = ["fontSize": 100,
                             "totalIterations": 1,
                             "tiltMap": 1,
                             "fontName": "Courier"]
            remoteConfig.setDefaults(defaultValues as! [String : NSObject])
            remoteConfig.fetchWithExpirationDuration(0, completionHandler: { (FIRRemoteConfigFetchStatus, NSError) in
                switch FIRRemoteConfigFetchStatus {
                case .Success:
                    self.remoteConfig.activateFetched()
                    print("fetch succeed \(self.remoteConfig.configValueForKey("font")), result: \(self.remoteConfig.activateFetched())")
                    break
                case .Failure:
                    print("fetch failed")
                    break
                default:
                    print("default")
                }
            })
            
            let fontSize = CGFloat(remoteConfig["fontSize"].numberValue!)
            let fontName = remoteConfig["fontName"].stringValue!
            let tiltMapping = Int(remoteConfig["tiltMap"].numberValue!)
            let totalIterations = Int(remoteConfig["totalIterations"].numberValue!)
            let textWindow = CGFloat(remoteConfig["textWindow"].numberValue!)
            
            tvc.textWindow = textWindow
            tvc.tiltMapping = tiltMapping
            tvc.totalIterations = totalIterations
            tvc.fontName = fontName
            tvc.fontSize = fontSize
        }
    }
}