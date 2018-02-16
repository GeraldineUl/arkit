import UIKit
import ARKit

enum FunctionMode {
  case none
  case placeObject(String)
}

class ExploreViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  
  @IBOutlet var sceneView: ARSCNView!
  @IBOutlet weak var polaroidButton: UIButton!
  @IBOutlet weak var crosshair: UIView!
  @IBOutlet weak var messageLabel: UILabel!
  @IBOutlet weak var trackingInfo: UILabel!
  
  //FunctionMode wird auf none gesetzt, sodass beim Start keine Funktion (placeObject) statt finden kann
  var currentMode: FunctionMode = .none
  var objects: [SCNNode] = []
  
 //Variable für die Beschreibung des Polaroids - Zukunft
  var PolaroidDescription: String = "TEST"
  //Node für Text
  let textNode = SCNNode()


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
  // ein Bild ausgewählt hat. Damit das Bild später verwendet werden kann, wir es
  // auf eine eigene Variable namens "pickedTexture" gespeichert. Diese wird später
  // beim Zusammensetzen der Box einfach als Textur verwendet.
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
      self.pickedTexture = pickedImage
    }
    dismiss(animated: true, completion: nil)
  }
  

  // Falls der Nutzer kein Bild wählen möchte und einfach auf Cancel drückt,
  // dann wird der Dialog vom Bildschirm entfernt.
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    dismiss(animated: true, completion: nil)
  }
  
  @IBAction func didTapPolaroid(_ sender: Any) {
    //Modus wird in placeObject umgewandelt
    //Polaroids können nun plaziert werden
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
    //Modus wird in placeObject umgewandelt
    //Polaroids können nun plaziert werden
    currentMode = .placeObject("Models.scnassets/polaroid/polaroid.scn")
    //polaroidButton muss ausgwählt sein
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
  
  //alle Objekte werden durch diese Funktion entfernt
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
  }



extension ExploreViewController: ARSCNViewDelegate {


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

  
//ich habe meinen Stand mal drinnen gelassen :)
//  func addDescription(){
//
//
//    let text = SCNText(string: self.PolaroidDescription, extrusionDepth: 1)
//    let material = SCNMaterial()
//    material.diffuse.contents = UIColor.gray
//    text.materials = [material]
//
//    textNode.position = SCNVector3(x: -0.1, y: 0.02, z: 0)
//    textNode.scale = SCNVector3(x: 0.005, y:0.005, z:0.005)
//    textNode.geometry = text
//
//
//
//  }

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
          //das alles passiert sobald der Mode .placeObject auftritt und ein Polaroid plaziert werden soll
        case .placeObject(let name):
          //neue Variable modelClone um die scene zu klonen
          let modelClone = SCNScene(named: name)!.rootNode.clone()
          //Position
          modelClone.eulerAngles = SCNVector3(200.degreesToRadians,0,0)
        
          if self.polaroidButton.isSelected {
            //hier wird das ausgewählt Bild als Textur übergeben
            if let image = self.pickedTexture {
              updateTextureOnBoxes(modelClone, image: image)
            }
          }
//          self.addDescription()
          self.objects.append(modelClone)
          node.addChildNode(modelClone)
//          node.addChildNode(self.textNode)



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

//Rotation des Polaroids in Grad/Radians angeben
extension Int{
  var degreesToRadians: Double{
    return Double(self) * .pi/100
  }
}








