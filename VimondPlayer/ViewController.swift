//
//  ViewController.swift
//  VimondPlayer
//
//  Created by Mark Louie Angeles on 24/01/2017.
//  Copyright © 2017 Mark Louie Angeles. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import Alamofire

enum HMACAlgorithm {
    case MD5, SHA1, SHA224, SHA256, SHA384, SHA512
    
    func toCCHmacAlgorithm() -> CCHmacAlgorithm {
        var result: Int = 0
        switch self {
        case .MD5:
            result = kCCHmacAlgMD5
        case .SHA1:
            result = kCCHmacAlgSHA1
        case .SHA224:
            result = kCCHmacAlgSHA224
        case .SHA256:
            result = kCCHmacAlgSHA256
        case .SHA384:
            result = kCCHmacAlgSHA384
        case .SHA512:
            result = kCCHmacAlgSHA512
        }
        return CCHmacAlgorithm(result)
    }
    
    func digestLength() -> Int {
        var result: CInt = 0
        switch self {
        case .MD5:
            result = CC_MD5_DIGEST_LENGTH
        case .SHA1:
            result = CC_SHA1_DIGEST_LENGTH
        case .SHA224:
            result = CC_SHA224_DIGEST_LENGTH
        case .SHA256:
            result = CC_SHA256_DIGEST_LENGTH
        case .SHA384:
            result = CC_SHA384_DIGEST_LENGTH
        case .SHA512:
            result = CC_SHA512_DIGEST_LENGTH
        }
        return Int(result)
    }
}

class ViewController: UIViewController, AVAssetResourceLoaderDelegate {
    
    var licenseKey = ""
    var urlKey = ""
    let resourceRequestDispatchQueue = dispatch_queue_create("com.example.apple-samplecode.resourcerequests", DISPATCH_QUEUE_SERIAL)
    
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
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func didPressPlay(sender: UIButton) {

        /*
         Sample m3u8 links
         http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8
         https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8
    
         */
//        self.cryptoSha1()
//        self.callPlayer("https://licenseproxy.ha.pldt-first.vimondtv.com/license/fairplay/4471?timeStamp=2017-01-26T06%3A14%3A08%2B0000&contract=5d82edc495a5dc347769cc50aee91945&account=source")
        
//        self.callPlayer("https://gqS2AdgZSm.akamaized.net/2/stage/a75a5/TGIS_The_Movie_4491_739b(4491_ISMUSP).ism/TGIS_The_Movie_4491_739b(4491_ISMUSP).m3u8", content: NSDictionary())
        
        self.requestPlayBackURL()
        
    }
    
    func callPlayer(url: String, content : NSDictionary) {
        print("contet = \(content)")
        
        let videoURL = NSURL(string:url)
        
        let asset = AVURLAsset(URL: videoURL!, options: nil)
        self.fetchAppCertificateDataWithCompletionHandler { _ in
            /*
             Create an asset for the media specified by the playlist url. Calling the setter
             for the asset property will then invoke a method to load and test the necessary asset
             keys before playback.
             */
            
            asset.resourceLoader.setDelegate(self, queue: self.resourceRequestDispatchQueue)
            let item = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: item)
            
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            
            self.presentViewController(playerViewController, animated: true) {
//                playerViewController.player!.play()
                
            }
           
           
        }
        
        
    
    }
    
    func requestPlayBackURL() {
        
        let link = "http://52.43.9.97/slgapi/v1/playback_url/4487/HLS"
        let contentHeader : [String:String] = ["organization":"SLGIOS",
                                               "apikey":"ii34JCkSdYA90G7t0EPeAirJMpDyj8DV"]
        
        Alamofire.request(.GET, link, parameters: nil, encoding: ParameterEncoding.JSON, headers: contentHeader).responseJSON { (response) in
            
            print(response)
            if response.result.error == nil {
                
                let dictionaryResponse = response.result.value as! NSDictionary
                let result = dictionaryResponse["result"] as! NSDictionary
                self.licenseKey = result["license_uri"] as! String
                self.urlKey = result["playback_url"] as! String
                self.callPlayer(self.urlKey, content: NSDictionary())
                
            }else {
                print("Erorr = \(response.result.error!)")
            }
            
        }
        
    }
    
    func cryptoSha1() {
        
        var stringToSign = "GET\n/api/smg/asset/4471/play\nThu, 26 Jan 2017 13:31:00 +0800"
        let apiSecret = "0Cq7oN3qSO8zNBtpnJgbxIaxufmFmFemZfumCLQKvzEzc"
        stringToSign.hmac(HMACAlgorithm.SHA1, key: apiSecret)
        print("Converted = \(stringToSign.hmac(HMACAlgorithm.SHA1, key: apiSecret))")
        
    }
    
    // MARK: Delegate
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
   

}

extension String {
    func sha1() -> String {
        
        let data = self.dataUsingEncoding(NSUTF8StringEncoding)!
        var digest = [UInt8](count:Int(CC_SHA1_DIGEST_LENGTH), repeatedValue: 0)
        CC_SHA1(data.bytes, CC_LONG(data.length), &digest)
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joinWithSeparator("")
        
    }
    
    func hmac(algorithm: HMACAlgorithm, key: String) -> String {
        
        let cKey = key.cStringUsingEncoding(NSUTF8StringEncoding)
        let lengthKey = Int(strlen(cKey!))
        let cData = self.cStringUsingEncoding(NSUTF8StringEncoding)
        let lengthData = Int(strlen(cData!))
        var result = [CUnsignedChar](count: Int(algorithm.digestLength()), repeatedValue: 0)
        CCHmac(algorithm.toCCHmacAlgorithm(), cKey!, lengthKey, cData!, lengthData, &result)
        let hmacData:NSData = NSData(bytes: result, length: (Int(algorithm.digestLength())))
        let hmacBase64 = hmacData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding76CharacterLineLength)

        return String(hmacBase64)
    }

}

/*
 
 
 
 http://vimond-rest-api.ha.pldt-first.vimondtv.com/api/smg/asset/4465/play
 
 NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
 
 AVURLAsset * asset = [AVURLAsset URLAssetWithURL:linkUrl options:@{AVURLAssetHTTPCookiesKey : cookies}];
 
 AVPlayerItem * item = [AVPlayerItem playerItemWithAsset:asset];
 
 AVPlayer *player = [[AVPlayer alloc] initWithPlayerItem:item];
 
 AVPlayerViewController *playerVC = [[AVPlayerViewController alloc]init];
 
 NSMutableDictionary *cookieProperties = [NSMutableDictionary dictionary];
 [cookieProperties setObject:@"testCookie" forKey:NSHTTPCookieName];
 [cookieProperties setObject:@"someValue123456" forKey:NSHTTPCookieValue];
 [cookieProperties setObject:@"www.example.com" forKey:NSHTTPCookieDomain];
 [cookieProperties setObject:@"www.example.com" forKey:NSHTTPCookieOriginURL];
 [cookieProperties setObject:@"/" forKey:NSHTTPCookiePath];
 [cookieProperties setObject:@"0" forKey:NSHTTPCookieVersion];
 
 // set expiration to one month from now or any NSDate of your choosing
 // this makes the cookie sessionless and it will persist across web sessions and app launches
 /// if you want the cookie to be destroyed when your app exits, don't set this
 [cookieProperties setObject:[[NSDate date] dateByAddingTimeInterval:2629743] forKey:NSHTTPCookieExpires];
 
 NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
 [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
 
 // Header
 NSMutableDictionary * headers = [NSMutableDictionary dictionary];
 [headers setObject:@"Your UA" forKey:@"User-Agent"];
 AVURLAsset * asset = [AVURLAsset URLAssetWithURL:URL options:@{@"AVURLAssetHTTPHeaderFieldsKey" : headers}];
 AVPlayerItem * item = [AVPlayerItem playerItemWithAsset:asset];
 self.player = [[AVPlayer alloc] initWithPlayerItem:item];
 
 
 
 */

