//
//  CustomSegue.swift
//  TextScroll
//
//  Created by cssummer16 on 7/22/16.

//  From https://gist.github.com/marcboeren/165ed7de30178acfdad4
//

import UIKit

class SlideLeft: UIStoryboardSegue {
    
    override func perform()
    {
        let src = self.sourceViewController as UIViewController
        let dst = self.destinationViewController as UIViewController
        
        src.view.superview?.insertSubview(dst.view, aboveSubview: src.view)
        dst.view.transform = CGAffineTransformMakeTranslation(src.view.frame.size.width, 0)
        
        UIView.animateWithDuration(0.6,
                                   delay: 0.0,
                                   usingSpringWithDamping: 3,
                                   initialSpringVelocity: 4,
                                   options: UIViewAnimationOptions.CurveEaseInOut,
                                   animations: {
                                    dst.view.transform = CGAffineTransformMakeTranslation(0, 0)
            },
                                   completion: { finished in
                                    src.presentViewController(dst, animated: false, completion: nil)
            }
        )
    }
}

class SlideRight: UIStoryboardSegue {
    
    override func perform()
    {
        let src = self.sourceViewController as UIViewController
        let dst = self.destinationViewController as UIViewController
        
        src.view.superview?.insertSubview(dst.view, belowSubview: src.view)
        src.view.transform = CGAffineTransformMakeTranslation(0, 0)
        
        UIView.animateWithDuration(0.6,
                                   delay: 0.0,
                                   usingSpringWithDamping: 3,
                                   initialSpringVelocity: 4,
                                   options: UIViewAnimationOptions.CurveEaseInOut,
                                   animations: {
                                    src.view.transform = CGAffineTransformMakeTranslation(src.view.frame.size.width, 0)
            },
                                   completion: { finished in
                                    src.dismissViewControllerAnimated(false, completion: nil)
            }
        )
    }
}