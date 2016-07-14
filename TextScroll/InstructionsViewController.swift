//
//  InstructionsViewController.swift
//  TextScroll
//
//  Created by Michelle Feng on 7/11/16.
//  Copyright © 2016 cssummer16. All rights reserved.
//

import UIKit

class InstructionsViewController: UIViewController {
    
    @IBOutlet weak var nextButton: UIButton!
    //Info passed from tutorial VC to be sent to test VC
    var controlSwitchIsOn = false
    var tiltMapping = 1
    var iteration = -1
    var finishedTutorial = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        self.nextButton.layer.cornerRadius = 10
        self.nextButton.clipsToBounds = true
    }
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        //Passes switch settings to next screen
        if segue.identifier=="toTestViewController" {
            let tvc=segue.destinationViewController as! TestViewController
            tvc.switchIsOn = controlSwitchIsOn
            tvc.iteration = iteration
            tvc.finishedTutorial = finishedTutorial
            tvc.tiltMapping = tiltMapping
        }
    }
}