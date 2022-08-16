//
//  ViewController.swift
//  VoiceControlledAR
//
//  Created by Souvik Das on 15/08/22.
//

import UIKit
import RealityKit
import ARKit
import Speech

class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    var astronautEntity : Entity?
    
    var moveToLocation: Transform = Transform()
    var moveDuration: Double = 5
    
    let speechRecognizer = SFSpeechRecognizer()
    let speechRequest = SFSpeechAudioBufferRecognitionRequest()
    var speechTask = SFSpeechRecognitionTask()
    
    let audioEngine = AVAudioEngine()
    let audioSession = AVAudioSession.sharedInstance()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        
        astronautEntity = try? Entity.load(named: "robo")
        
//        DispatchQueue.main.async {
//            self.astronautEntity = try? Entity.load(named: "robo")
////            print("Entity loaded")
//            self.startARSession()
//        }
//        let url = URL(string: "https://drive.google.com/file/d/1t8bPj-rbx23sdqPAR7E7ZLoL8JE6HcJE/view?usp=sharing")
//                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//                let destination = documents.appendingPathComponent(url!.lastPathComponent)
//                let session = URLSession(configuration: .default,
//                                              delegate: nil,
//                                         delegateQueue: nil)
//
//                var request = URLRequest(url: url!)
//                request.httpMethod = "GET"
//
//                let downloadTask = session.downloadTask(with: request, completionHandler: { (location: URL?,
//                                          response: URLResponse?,
//                                             error: Error?) -> Void in
//
//                    let fileManager = FileManager.default
//
//                    if fileManager.fileExists(atPath: destination.path) {
//                        try! fileManager.removeItem(atPath: destination.path)
//                    }
//                    try! fileManager.moveItem(atPath: location!.path,
//                                              toPath: destination.path)
//
//                    DispatchQueue.main.async {
//                        do {
//                            self.astronautEntity = try Entity.load(contentsOf: destination)
//                            print("ENTITY FOUND")
//                            self.startARSession()
//                        } catch {
//                            print("Fail loading entity.")
//                        }
//                    }
//                })
//                downloadTask.resume()
        
        startARSession()
        //tap detection
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer: ))))
        
    
        startSpeechRecognition()
    }
    
    @objc
    func handleTap(recognizer: UITapGestureRecognizer) {
        
        //tap location (2d point)
        let taplocation = recognizer.location(in: arView)
        
        //convert 2d loc to 3d -> raycasting
        let results = arView.raycast(from: taplocation, allowing: .estimatedPlane, alignment: .horizontal)
        
        //if plane is detected
        if let firstResult = results.first{
            
            //3D position
            let worldPosition = simd_make_float3(firstResult.worldTransform.columns.3)
            
            placeObject(object: astronautEntity!, position: worldPosition)
//            move(direction: "forward")
        }
    }
    
    func startARSession(){
        
        arView.automaticallyConfigureSession = true
        
        //plane detection
        let configure = ARWorldTrackingConfiguration()
        configure.planeDetection = [.horizontal]
        configure.environmentTexturing = .automatic
        
//        arView.debugOptions = .showAnchorGeometry
        arView.session.run(configure)
        
    }
    
    func placeObject(object: Entity, position: SIMD3<Float>) {
        
        //Create an enchor at the 3d location
        let objectAnchor = AnchorEntity(world: position)
        //Tie the 3d model to the anchor
        objectAnchor.addChild(object)
        //add the anchor to the scence
        arView.scene.addAnchor(objectAnchor)
    }
    
    //Object movement
    func move(direction: String){
        
        switch direction {
            
        case "forward":
            moveToLocation.translation = (astronautEntity?.transform.translation)! + simd_float3(x: 0, y: 0, z: 20)
            astronautEntity?.move(to: moveToLocation, relativeTo: astronautEntity, duration: moveDuration)
            
            //animation
            walkAnimation(moveDuration: moveDuration)
            
        case "back":
            moveToLocation.translation = (astronautEntity?.transform.translation)! + simd_float3(x: 0, y: 0, z: -20)
            astronautEntity?.move(to: moveToLocation, relativeTo: astronautEntity, duration: moveDuration)
            
            //animation
            walkAnimation(moveDuration: moveDuration)
            
        case "left":
            let rotatetoAngle = simd_quatf(angle: GLKMathDegreesToRadians(-90), axis: SIMD3(x: 0, y: 1, z: 0))
            
            astronautEntity?.setOrientation(rotatetoAngle, relativeTo: astronautEntity)
            
        case "right":
            let rotatetoAngle = simd_quatf(angle: GLKMathDegreesToRadians(90), axis: SIMD3(x: 0, y: 1, z: 0))
            
            astronautEntity?.setOrientation(rotatetoAngle, relativeTo: astronautEntity)
            
            
            
            
        default:
            print("NO MOVEMENTS")
        }
    }
    
    func walkAnimation(moveDuration: Double){
        if let astronautAnimation = astronautEntity?.availableAnimations.first{
            
            //play
            astronautEntity?.playAnimation(astronautAnimation.repeat(duration: moveDuration), transitionDuration: 0.5, startsPaused: false)
            
            
        }
        else {
            print("No anim")
        }
    }
    
    //speech
    
    func startSpeechRecognition() {
        
        requestPermission()
        
        startAudioRecording()
        
        speechRecognize()
    }
    
    func requestPermission(){
        
        SFSpeechRecognizer.requestAuthorization({
            (authorizationStatus) in
            
            if (authorizationStatus == .authorized){
                print("authorized")
            }else if(authorizationStatus == .denied){
                print("denied")
            }else if(authorizationStatus == .notDetermined){
                print("waiting")
            }else if(authorizationStatus == .restricted){
                print("not available")
            }else{
                print("nothing worked")
            }
        })
    }
    
    func startAudioRecording(){
        
        //ip node
        let node = audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {(buffer, _) in
            
            //pass the audio samples from buffer to speech recog
            self.speechRequest.append(buffer)
        }
        
        //audio engine start
        do{
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            audioEngine.prepare()
            try audioEngine.start()
        }
        catch{
            
        }
    }
    
    func speechRecognize(){
        
        //availability
        guard let speechRecognizer = SFSpeechRecognizer()
        else {
            print("Speech recog not available")
            return
        }
        if(speechRecognizer.isAvailable == false){
            print("temp not avail")
        }
        
        //recognize text
        var count = 0
        speechTask = speechRecognizer.recognitionTask(with: speechRequest, resultHandler: {(result, error) in
            
            count = count + 1
            
            if (count == 1) {
            guard let result = result else {return}
            let recognizedText = result.bestTranscription.segments.last
            
            //robo move
                self.move(direction: recognizedText!.substring)
            }else if(count>=3){
                count = 0
            }
        })
    }
    
    
    
}
