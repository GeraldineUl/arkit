

import UIKit
import ARKit

enum FunctionMode {
  case none
  case placeObject(String)
}

class HomeHeroViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  
  @IBOutlet var sceneView: ARSCNView!
  @IBOutlet weak var polaroidButton: UIButton!
  @IBOutlet weak var crosshair: UIView!
  @IBOutlet weak var messageLabel: UILabel!
  @IBOutlet weak var trackingInfo: UILabel!
  
  var currentMode: FunctionMode = .none
  var objects: [SCNNode] = []
 
 

  let imagePicker = UIImagePickerController()
  var pickedTexture : UIImage?
  


  
  override func viewDidLoad() {
    //Hier wird dem Imagepicker gesagt, dass er dem HomeViewController bescheid geben soll, sobald ein Bild ausgewählt wurde
    imagePicker.delegate = self

    
    super.viewDidLoad()
    runSession()
    trackingInfo.text = ""
    messageLabel.text = ""
    selectPolaroid()
    imagePicker.delegate = self
    
  }
  

  // Diese Delegate Funktion wird aufgerufen, sobald der Nutzer im Image Picker
  // ein Bild ausgewählt hat. Damit das Bild später verwendet werden kann, speichern
  // wir es uns auf eine eigene Variable namens "pickedTexture". Die verwenden
  // wir beim Zusammensetzen der Box später einfach als Textur. Also kein Paket mehr,
  // sondern ein Selfie als Textur :D
  
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
      self.pickedTexture = pickedImage
    }
    
    dismiss(animated: true, completion: nil)
  }
  

  // Falls der Nutzer kein Bild wählen möchte und einfach auf Cancel drückt,
  // machen wir einfach nix, sondern werfen nur den Dialog vom Bildschirm.
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    dismiss(animated: true, completion: nil)
  }
  
  
  @IBAction func didTapPolaroid(_ sender: Any) {
    currentMode = .placeObject("Models.scnassets/polaroid/polaroid.scn")
    selectButton(polaroidButton)
    
    //Funktion zum Auswählen aus der Fotobibliothek
    
    imagePicker.allowsEditing = false
    imagePicker.sourceType = .photoLibrary
    present(self.imagePicker, animated: true, completion: nil)
  }

  
  @IBAction func didTapReset(_ sender: Any) {
    removeAllObjects()
  }
  
  func selectPolaroid() {
    currentMode = .placeObject("Models.scnassets/polaroid/polaroid.scn")
    selectButton(polaroidButton)
  }
  
  func selectButton(_ button: UIButton) {
    unselectAllButtons()
    button.isSelected = true
  }
  
  func unselectAllButtons() {
    [polaroidButton].forEach {
      $0?.isSelected = false
    }
  }
  
  func removeAllObjects() {
    for object in objects {
      object.removeFromParentNode()
    }
    
    objects = []
  }
  
  func runSession() {
    sceneView.delegate = self
    let configuration = ARWorldTrackingConfiguration()
    configuration.planeDetection = .horizontal
    configuration.isLightEstimationEnabled = true
    sceneView.session.run(configuration)
    #if DEBUG
      sceneView.debugOptions = ARSCNDebugOptions.showFeaturePoints
    #endif
  }
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    if let hit = sceneView.hitTest(viewCenter, types: [.existingPlaneUsingExtent]).first {
      sceneView.session.add(anchor: ARAnchor(transform: hit.worldTransform))
      return
    } else if let hit = sceneView.hitTest(viewCenter, types: [.featurePoint]).last {
      sceneView.session.add(anchor: ARAnchor(transform: hit.worldTransform))
      return
    }
  }


  func updateTrackingInfo() {

    guard let frame = sceneView.session.currentFrame else {
      return
    }
    switch frame.camera.trackingState {
      case .limited(let reason):
        switch reason {
          case .excessiveMotion:
            trackingInfo.text = "Limited Tracking: Excessive Motion"
          case .insufficientFeatures:
            trackingInfo.text = "Limited Tracking: Insufficient Details"
          default:
            trackingInfo.text = "Limited Tracking"
        }
      default:
        trackingInfo.text = ""
    }

    guard let lightEstimate = frame.lightEstimate?.ambientIntensity else {
      return
    }

    if lightEstimate < 100 {
      trackingInfo.text = "Limited Tracking: Too Dark"
    }
  }
  
//  // func selectImage
//  
//  func createPolaroid(){
//
//
//      let polaroidClone = SCNScene(named:"Models.scnassets/polaroid/polaroid.scn")!.rootNode.clone()
//
//      let imageNode = polaroidClone.childNode(withName: "plane", recursively: true)
//
//      if let polaroid = imageNode {
//        let geo = polaroid.geometry as! SCNPlane
//
//        let imageMaterial = SCNMaterial()
//        imageMaterial.diffuse.contents = selectedImage
//        geo.materials = [imageMaterial]
//      }
//
//  }
}



extension HomeHeroViewController: ARSCNViewDelegate {


  func session(_ session: ARSession, didFailWithError error: Error) {

    showMessage(error.localizedDescription, label: messageLabel, seconds: 2)

  }

  func sessionWasInterrupted(_ session: ARSession) {

    showMessage("Session interuppted", label: messageLabel, seconds: 2)

  }

  func sessionInterruptionEnded(_ session: ARSession) {

    showMessage("Session resumed", label: messageLabel, seconds: 2)
    removeAllObjects()
    runSession()

  }



  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {

    DispatchQueue.main.async {
      self.updateTrackingInfo()
    }

  }


  func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {

    DispatchQueue.main.async {
      if let planeAnchor = anchor as? ARPlaneAnchor {
        #if DEBUG
          let planeNode = createPlaneNode(center: planeAnchor.center, extent: planeAnchor.extent)
          node.addChildNode(planeNode)
  
        #endif
      } else {
        
        switch self.currentMode {
        case .none:
          break
        case .placeObject(let name):
          let modelClone = SCNScene(named: name)!.rootNode.clone()
         
          
//          if self.polaroidButton.isSelected || self.beerButton.isSelected {
//            updatePhysicsOnBoxes(modelClone)
//          }
          
          // 5)
          // ACHTUNG: HIER GUCKEN!
          // Hier rufen wir eine kleine Hilfsmethode auf, der wir unser
          // selbst ausgewähltes Bild übergeben. Natürlich prüfen wir erst, ob eins ausgewählt wurde
          //  func createPolaroid(){
          //
          //
          //      let polaroidClone = SCNScene(named:"Models.scnassets/polaroid/polaroid.scn")!.rootNode.clone()
          //
          //      let imageNode = polaroidClone.childNode(withName: "plane", recursively: true)
          //
          //      if let polaroid = imageNode {
          //        let geo = polaroid.geometry as! SCNPlane
          //
          //        let imageMaterial = SCNMaterial()
          //        imageMaterial.diffuse.contents = selectedImage
          //        geo.materials = [imageMaterial]
          //      }
          //
          //  }
          
          if self.polaroidButton.isSelected {
            //  let imageNode = polaroidClone.childNode(withName: "plane", recursively: true)

            if let image = self.pickedTexture {
              updateTextureOnBoxes(modelClone, image: image)
            }
          }
          self.objects.append(modelClone)
          node.addChildNode(modelClone)
          
          

        }
      }
    }
  }
  
  func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {

    DispatchQueue.main.async {
      if let planeAnchor = anchor as? ARPlaneAnchor {
        updatePlaneNode(node.childNodes[0], center: planeAnchor.center, extent: planeAnchor.extent)
      }
    }


  func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
    guard anchor is ARPlaneAnchor else { return }
    removeChildren(inNode: node)
  }

  }
}








