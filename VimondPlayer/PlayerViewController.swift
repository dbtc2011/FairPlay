/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See the Apple Developer Program License Agreement for this file's licensing information.
All use of these materials is subject to the terms of the Apple Developer Program License Agreement.

Abstract:
PlayerViewController.swift: Sample player view controller. Illustrates how to implement and install an AVAssetResourceLoader delegate that will handle FairPlay Streaming key requests.
*/


import Foundation
import UIKit
import AVFoundation
import Alamofire

// MARK: AVAssetResourceLoaderDelegate

class AssetLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    // MARK: Properties
    var licenseKey = ""

    /**
        Your custom scheme name that indicates how to obtain the content 
        key. This value is specified in the URI attribute in the EXT-X-KEY
        tag in the playlist.
    */
    static let URLScheme = "skd"
    
    /// The application certificate that is retrieved from the server.
    var fetchedCertificate: NSData?

    // MARK: Functions

    /**
        ADAPT: YOU MUST IMPLEMENT THIS METHOD.
    
        - returns: Content Key Context (CKC) message data specific to this request.
    */
    var ckcData: NSData?
    /**
        ADAPT: YOU MUST IMPLEMENT THIS METHOD.

        Sends the SPC to a Key Server that contains your Key Security
        Module (KSM). The KSM decrypts the SPC and gets the requested
        CK from the Key Server. The KSM wraps the CK inside an encrypted
        Content Key Context (CKC) message, which it sends to the app.

        The application may use whatever transport forms and protocols
        it needs to send the SPC to the Key Server.
    
        - returns: The CKC from the server.
    */
    func contentKeyFromKeyServerModuleWithRequestData(requestBytes: NSData, assetString: String, expiryDuration: NSTimeInterval) throws -> NSData {
        
        let ksmUrl = NSURL(string: self.licenseKey)
        let request = NSMutableURLRequest(URL: ksmUrl!)
        request.HTTPMethod = "POST"
        
        print(requestBytes.length)
        print(requestBytes)
        let postString = requestBytes.base64EncodedStringWithOptions([])
        var response: NSURLResponse?
        request.HTTPBody = postString.dataUsingEncoding(NSUTF8StringEncoding)
        ckcData = try NSURLConnection.sendSynchronousRequest(request, returningResponse: &response)
        
        
        //ckcData = NSData(base64EncodedData: res)
        
        /*print(requestBytes.length)
        print(requestBytes)
        Alamofire.upload(
            .POST,
            "http://192.168.2.13:3000/ksm.php",
            data: requestBytes
        )*/
        
        print(NSString(data: ckcData!, encoding: NSUTF8StringEncoding)!);
        print(ckcData!.length)
        // If the key server provided a CKC, return it.
        if let ckcData = NSData(base64EncodedData: ckcData!, options: []) {
            print(ckcData.length)
            return ckcData;
        }

        /*
            Otherwise, the CKC was not provided by key server. Fail with bogus error.
            Generate an error describing the failure.
        */
        throw NSError(domain: "com.example.apple-samplecode", code: 0, userInfo: [
            NSLocalizedDescriptionKey: NSLocalizedString("Item cannot be played.", comment: "Item cannot be played."),
            NSLocalizedFailureReasonErrorKey: NSLocalizedString("Could not get the content key from the Key Server.", comment: "Failure to successfully send the SPC to the Key Server and get the content key from the returned Content Key Context (CKC) message.")
        ])
    }

    /**
        ADAPT: YOU MUST IMPLEMENT THIS METHOD:
    
        Get the application certificate from the server in DER format.
    */
    func fetchAppCertificateDataWithCompletionHandler(handler: NSData? -> Void) {

        /*
            This needs to be implemented to conform to your protocol with the backend/key security module.
            At a high level, this function gets the application certificate from the server in DER format.
        */
        let certificatePath = NSBundle.mainBundle().pathForResource("fairplay", ofType: "cer")
        fetchedCertificate = NSData(contentsOfFile: certificatePath!)
        
        // If the server provided an application certificate, return it.
        if let fetchedCertificate = fetchedCertificate {
            handler(fetchedCertificate)
            return
        }
        
        // Otherwise, failed to get application certificate from the server.
        
        fetchedCertificate = nil
        
        // If the server provided an application certificate, return it.
        handler(fetchedCertificate)
    }
    
    /*
        resourceLoader:shouldWaitForLoadingOfRequestedResource:
        
        When iOS asks the app to provide a CK, the app invokes
        the AVAssetResourceLoader delegate’s implementation of
        its -resourceLoader:shouldWaitForLoadingOfRequestedResource:
        method. This method provides the delegate with an instance
        of AVAssetResourceLoadingRequest, which accesses the
        underlying NSURLRequest for the requested resource together
        with support for responding to the request.
    */
    func resourceLoader(resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        // Get the URL request object for the requested resource.

        /*
            Your URI scheme must be a non-standard scheme for AVFoundation to invoke your
            AVAssetResourceLoader delegate for help in loading it.
        */
        print("Loading = \(loadingRequest.request.URLString) & \(AssetLoaderDelegate.URLScheme)")
        guard let url = loadingRequest.request.URL where url.scheme == AssetLoaderDelegate.URLScheme else {
            print("URI scheme name does not match our scheme.")
            return false
        }
        
        // Get the URI for the content key.
        guard let assetString = url.host, let assetID = assetString.dataUsingEncoding(NSUTF8StringEncoding) else {
            return false
        }
        
        // Get the application certificate from the server.
        guard let fetchedCertificate = fetchedCertificate else {
            print("Failed to get Application Certificate from key server.")
            return false
        }
        do {
            // MARK: ADAPT: YOU MUST CALL: `streamingContentKeyRequestDataForApp(_:options:)`
            
            /*
                ADAPT: YOU MUST CALL : `streamingContentKeyRequestDataForApp(_:options:)`.
                to obtain the SPC message from iOS to send to the Key Server.
            */
            let requestedBytes = try loadingRequest.streamingContentKeyRequestDataForApp(fetchedCertificate, contentIdentifier: assetID, options: nil)

            let expiryDuration: NSTimeInterval = 0.0
            
            let responseData = try contentKeyFromKeyServerModuleWithRequestData(requestedBytes, assetString: assetString, expiryDuration: expiryDuration)
            
            guard let dataRequest = loadingRequest.dataRequest else {
                print("Failed to get instance of AVAssetResourceLoadingDataRequest (loadingRequest.dataRequest).")
                return false
            }

            /*
                The Key Server returns the CK inside an encrypted Content Key Context (CKC) message in response to
                the app’s SPC message.  This CKC message, containing the CK, was constructed from the SPC by a
                Key Security Module in the Key Server’s software.
            */
            
            // Provide the CKC message (containing the CK) to the loading request.
            dataRequest.respondWithData(responseData)
            
            // Get the CK expiration time from the CKC. This is used to enforce the expiration of the CK.
            if let infoRequest = loadingRequest.contentInformationRequest where expiryDuration != 0.0 {
                /*
                    Set the date at which a renewal should be triggered.
                    Before you finish loading an AVAssetResourceLoadingRequest, if the resource
                    is prone to expiry you should set the value of this property to the date at
                    which a renewal should be triggered. This value should be set sufficiently
                    early enough to allow an AVAssetResourceRenewalRequest, delivered to your
                    delegate via -resourceLoader:shouldWaitForRenewalOfRequestedResource:, to
                    finish before the actual expiry time. Otherwise media playback may fail.
                */
                infoRequest.renewalDate = NSDate(timeIntervalSinceNow: expiryDuration)
                
                infoRequest.contentType = "application/octet-stream"
                infoRequest.contentLength = Int64(responseData.length)
                infoRequest.byteRangeAccessSupported = false
            }
            
            // Treat the processing of the requested resource as complete.
            loadingRequest.finishLoading()
            
            // The resource request has been handled regardless of whether the server returned an error.
            return true
            
        } catch let error as NSError {
            // Resource loading failed with an error.
            print("streamingContentKeyRequestDataForApp failure: \(error.localizedDescription)")
            loadingRequest.finishLoadingWithError(error)
            return false
        }
    }

    
    /*
        resourceLoader: shouldWaitForRenewalOfRequestedResource:

        Delegates receive this message when assistance is required of the application
        to renew a resource previously loaded by
        resourceLoader:shouldWaitForLoadingOfRequestedResource:. For example, this
        method is invoked to renew decryption keys that require renewal, as indicated
        in a response to a prior invocation of
        resourceLoader:shouldWaitForLoadingOfRequestedResource:. If the result is
        YES, the resource loader expects invocation, either subsequently or
        immediately, of either -[AVAssetResourceRenewalRequest finishLoading] or
        -[AVAssetResourceRenewalRequest finishLoadingWithError:]. If you intend to
        finish loading the resource after your handling of this message returns, you
        must retain the instance of AVAssetResourceRenewalRequest until after loading
        is finished. If the result is NO, the resource loader treats the loading of
        the resource as having failed. Note that if the delegate's implementation of
        -resourceLoader:shouldWaitForRenewalOfRequestedResource: returns YES without
        finishing the loading request immediately, it may be invoked again with
        another loading request before the prior request is finished; therefore in
        such cases the delegate should be prepared to manage multiple loading
        requests.
    */
    func resourceLoader(resourceLoader: AVAssetResourceLoader, shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest) -> Bool {
        return self.resourceLoader(resourceLoader, shouldWaitForLoadingOfRequestedResource: renewalRequest)
    }
}


/**
    KVO context used to differentiate KVO callbacks for this class versus other
    classes in its class hierarchy.
*/
private var playerViewControllerKVOContext = 0

// MARK: - View Controller

class PlayerViewController: UIViewController {
    // MARK: Properties

    
    var licenseKey = ""
    var urlKey = ""
    var content : NSMutableDictionary?
    let player = AVPlayer()
    
    var playerLayer: AVPlayerLayer? {
        return playerView.playerLayer
    }

    var playerItem: AVPlayerItem? {
        didSet {
            /*
                If needed, configure player item here before associating it with a player.
                (example: adding outputs, setting text style rules, selecting media options)
            */
            player.replaceCurrentItemWithPlayerItem(playerItem)
        }
    }

    /// Dispatch queue to use with the resource loader.
    let resourceRequestDispatchQueue = dispatch_queue_create("com.example.apple-samplecode.resourcerequests", DISPATCH_QUEUE_SERIAL)
    
    var loaderDelegate = AssetLoaderDelegate()

    var asset: AVURLAsset? {
        didSet {
            guard let newAsset = asset else { return }
            
            // Sets the delegate and dispatch queue to use with the resource loader.
            newAsset.resourceLoader.setDelegate(self.loaderDelegate, queue: resourceRequestDispatchQueue)

            asynchronouslyLoadURLAsset(newAsset)
        }
    }

    // Must load and test these asset keys before playing.
    static let assetKeysRequiredToPlay = [
        "playable"
    ]
    
    static let playerItemStatusKey = "player.currentItem.status"
    
    // MARK: ADAPT: Your media stream URL.

    /// Playlists are not hardcoded in a real app. Modify this to suit your app design.
    static let playlistURL = "https://s3-ap-southeast-1.amazonaws.com/pldt-first-vpc-vod-fragments/125c0/Farmen_Tvekampen_4426_89(4426_ISMUSP)_v4.ism/Farmen_Tvekampen_4426_89(4426_ISMUSP)_v4.m3u8"

    @IBOutlet weak var playerView: PlayerView!
    
    // MARK: Functions
    
    func asynchronouslyLoadURLAsset(newAsset: AVURLAsset) {
        /*
            Using AVAsset now runs the risk of blocking the current thread (the
            main UI thread) whilst I/O happens to populate the properties. It's
            prudent to defer our work until the properties we need have been loaded.
        */
        newAsset.loadValuesAsynchronouslyForKeys(PlayerViewController.assetKeysRequiredToPlay) {
            /*
                The asset invokes its completion handler on an arbitrary queue.
                To avoid multiple threads using our internal state at the same time
                we'll elect to use the main thread at all times, let's dispatch
                our handler to the main queue.
            */
            dispatch_async(dispatch_get_main_queue()) {
                /*
                    `self.asset` has already changed! No point continuing because
                    another `newAsset` will come along in a moment.
                */
                guard newAsset == self.asset else { return }
                
                /*
                    Test whether the values of each of the keys we need have been
                    successfully loaded.
                */
                for key in PlayerViewController.assetKeysRequiredToPlay {
                    var error: NSError?
                    
                    if newAsset.statusOfValueForKey(key, error: &error) == .Failed {
                        let stringFormat = NSLocalizedString("error.asset_key_%@_failed.description", comment: "Can't use this AVAsset because one of it's keys failed to load")
                        let message = String.localizedStringWithFormat(stringFormat, key)
                        
                        self.handleErrorWithMessage(message, error: error)
                        
                        return
                    }
                }
                
                // We can't play this asset.
                if !newAsset.playable {
                    let message = NSLocalizedString("error.asset_not_playable.description", comment: "Can't use this AVAsset because it isn't playable")
                    
                    self.handleErrorWithMessage(message)
                    
                    return
                }
                
                /*
                    We can play this asset. Create a new `AVPlayerItem` and make
                    it our player's current item.
                */
                self.playerItem = AVPlayerItem(asset: newAsset)
            }
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    
        // Observe the player item "status" property to determine when it is ready to play.
        addObserver(self, forKeyPath: PlayerViewController.playerItemStatusKey, options: [.New, .Initial], context: &playerViewControllerKVOContext)
        
        /* 
            When an iOS device is in AirPlay mode, FPS content will not play on an attached AppleTV
            unless AirPlay playback is set to full screen. 
        */
//        self.requestPlayBackURL()
        self.fetchContent()
        player.usesExternalPlaybackWhileExternalScreenIsActive = true

        playerView.playerLayer.player = player
        
        
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        player.pause()
        
        removeObserver(self, forKeyPath: PlayerViewController.playerItemStatusKey, context: &playerViewControllerKVOContext)
    }

    // MARK: - KVO Observation
    
    /*
        observeValueForKeyPath:ofObject:change:context

        Called when the value at the specified key path relative
        to the given object has changed.
        Start movie playback when the AVPlayerItem is ready to
        play.
        Report and error if the AVPlayerItem cannot be played.

        NOTE: this method is invoked on the main queue.
    */
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String: AnyObject]?, context: UnsafeMutablePointer<Void>) {
        // Make sure the this KVO callback was intended for this view controller.
        guard context == &playerViewControllerKVOContext else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
            return
        }
        
        // AVPlayerItem "status" property value observer.
        let rawStatus = change?[NSKeyValueChangeNewKey] as? Int
        let newStatus = rawStatus.map(AVPlayerItemStatus.init) ?? .Unknown
        
        if newStatus == .Failed {
            handleErrorWithMessage(player.currentItem?.error?.localizedDescription, error: player.currentItem?.error)
        }
        else if newStatus == .ReadyToPlay {
            /* 
                Once the AVPlayerItem becomes ready to play, i.e.
                playerItem.status == .ReadyToPlay,
                we can start playback using the associated player
                object. 
            */
            player.play()
        }
    }

    // MARK: - Error Handling
    
    func handleErrorWithMessage(message: String?, error: NSError? = nil) {
        NSLog("Error occured with message: \(message), error: \(error).")
        
        let alertTitle = NSLocalizedString("alert.error.title", comment: "Alert title for errors")
        let defaultAlertMessage = NSLocalizedString("error.default.description", comment: "Default error message when no NSError provided")
        
        let alert = UIAlertController(title: alertTitle, message: message == nil ? defaultAlertMessage : message, preferredStyle: .Alert)
        
        let alertActionTitle = NSLocalizedString("alert.error.actions.OK", comment: "OK on error alert")
        
        let alertAction = UIAlertAction(title: alertActionTitle, style: .Default, handler: nil)
        
        alert.addAction(alertAction)
        
        presentViewController(alert, animated: true, completion: nil)
    }
    
    //MARK: API Call
    
    func requestPlayBackURL() {
        
        let link = "http://52.43.9.97/slgapi/v1/playback_url/4425/HLS"
        let contentHeader : [String:String] = ["organization":"SLGIOS",
                                               "apikey":"ii34JCkSdYA90G7t0EPeAirJMpDyj8DV"]
        
        Alamofire.request(.GET, link, parameters: nil, encoding: ParameterEncoding.JSON, headers: contentHeader).responseJSON { (response) in
            
            print(response)
            if response.result.error == nil {
                
                let dictionaryResponse = response.result.value as! NSDictionary
                let result = dictionaryResponse["result"] as! NSDictionary
                let playback = result["playback"] as! NSDictionary
                let items = playback["items"] as! NSDictionary
                let item = items["item"] as! NSDictionary
                let license = item["license"] as! NSDictionary
                let urlKey = item["url"] as! String
                let licenseKey = license["@uri"] as! String
                
                let licenses = NSMutableArray()
                let urls = NSMutableArray()
                
                licenses.addObject(licenseKey)
                urls.addObject(urlKey)
                
                
                self.loaderDelegate.licenseKey = self.licenseKey
                self.loaderDelegate.fetchAppCertificateDataWithCompletionHandler { _ in
                    /*
                     Create an asset for the media specified by the playlist url. Calling the setter
                     for the asset property will then invoke a method to load and test the necessary asset
                     keys before playback.
                     */
                    let url = urls[0] as! String
                    
                    if let playlistURL = NSURL(string: url) {
                        self.asset = AVURLAsset(URL: playlistURL, options: nil)
                    }
                }
                
                
                
                
            }else {
                print("Erorr = \(response.result.error!)")
            }
            
        }
        
    }
    
    func fetchContent() {

        let link = "http://52.43.9.97/slgapi/v1/playback_url/4487/HLS"
        let contentHeader : [String:String] = ["organization":"SLGIOS",
                                               "apikey":"ii34JCkSdYA90G7t0EPeAirJMpDyj8DV"]
        
        
        Alamofire.request(.GET, link, parameters: nil, encoding: ParameterEncoding.JSON, headers: contentHeader).responseJSON { (response) in
            
            print(response)
            if response.result.error == nil {
                
                let dictionaryResponse = response.result.value as! NSDictionary
                let playback = dictionaryResponse["result"] as! NSDictionary

                self.licenseKey = playback["license_uri"] as! String
                self.urlKey = playback["playback_url"] as! String
                
                self.loaderDelegate.licenseKey = self.licenseKey
                self.loaderDelegate.fetchAppCertificateDataWithCompletionHandler { _ in
                    /*
                     Create an asset for the media specified by the playlist url. Calling the setter
                     for the asset property will then invoke a method to load and test the necessary asset
                     keys before playback.
                     */
                    
                    
                    if let playlistURL = NSURL(string: self.urlKey) {
                        self.asset = AVURLAsset(URL: playlistURL, options: nil)
                    }
                }
         
            }else {
                print("Erorr = \(response.result.error!)")
            }
            
        }
        
    }
}
