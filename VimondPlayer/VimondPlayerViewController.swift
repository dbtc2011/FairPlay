//
//  VimondPlayerViewController.swift
//  VimondPlayer
//
//  Created by Mark Louie Angeles on 01/02/2017.
//  Copyright © 2017 Mark Louie Angeles. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

// MARK: - Vimond Player View Controller
class VimondPlayerViewController: UIViewController {
    
    // MARK: Properties
    @IBOutlet weak var playerView: ViewPlayer!
    
    let player = AVPlayer()
    
    var duration : Double = 0.0

    var playerLayer: AVPlayerLayer? {
        return playerView.playerLayer
    }
    @IBOutlet weak var buttonPlay: UIButton!
    
    @IBOutlet weak var buttonFullScreen: UIButton!
    
    @IBOutlet weak var labelTime: UILabel!
    
    @IBOutlet weak var slider: UISlider!
    /*
    var asset: AVURLAsset? {
        didSet {
            guard let newAsset = asset else { return }
            
            // Sets the delegate and dispatch queue to use with the resource loader.
            newAsset.resourceLoader.setDelegate(self.loaderDelegate, queue: resourceRequestDispatchQueue)
            
            asynchronouslyLoadURLAsset(newAsset)
        }
    }
 */
    
    // MARK: View Life Cycle
    override func viewDidLoad() {
        
        self.temporarySetup()
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.player.usesExternalPlaybackWhileExternalScreenIsActive = true
        self.playerView.playerLayer.player = self.player
        
        
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    
    // MARK: Method
    func temporarySetup() {
        
        let url = "https://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4"
        let videoURL = NSURL(string:url)
        
        let asset = AVAsset(URL: videoURL!)
        let item = AVPlayerItem(asset: asset)
        self.player.replaceCurrentItemWithPlayerItem(item)
        
        self.duration = CMTimeGetSeconds(self.player.currentItem!.asset.duration)
        self.slider.minimumValue = 0.0
        self.slider.maximumValue = Float(self.duration)
        self.slider.value = 0.0
        
    }
    
    //MARK: Button Actions
    
    @IBAction func playClicked(sender: UIButton) {
        print("Play!!")
        self.player.play()
        
        print("Seekable = \(self.player.currentItem?.seekableTimeRanges)")
        
    }
    
    @IBAction func fullScreenClicked(sender: UIButton) {
    }
    
    // MARK: Slider Event
    
    @IBAction func sliderValueChanged(sender: UISlider) {
        
        print("Value Changed \(sender.value)")
        
        
    }
    
    
}


// MARK: - Player View
class ViewPlayer: UIView {
    // MARK: Properties
    
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        
        set {
            playerLayer.player = newValue
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    // MARK: Functions
    override class func layerClass() -> AnyClass {
        return AVPlayerLayer.self
    }
}
