//
//  MetricsViewController.swift
//  TextScroll
//
//  Created by Michelle Feng on 7/8/16.
//  Copyright © 2016 cssummer16. All rights reserved.
//

import UIKit
import Firebase

class MetricsViewController: UIViewController {
    /**
     Submits collected data to firebase
    */
    
    @IBOutlet weak var exitButton: UIButton!
    
    var masterData: Dictionary<String, [(Double, Double)]>! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        exitButton.layer.cornerRadius = 10
        exitButton.clipsToBounds = true
        
        //Upload data to firebase
        var rootRef: FIRDatabaseReference!
        rootRef = FIRDatabase.database().reference()
        let date = NSDate()
        rootRef.child("\(date)").setValue(masterData.printDict())
    }
}