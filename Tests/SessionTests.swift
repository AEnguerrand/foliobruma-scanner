import Foundation
import CoreImage

@main struct SessionTests {
 static func main() throws {
  let root=FileManager.default.temporaryDirectory.appendingPathComponent("sovenelia-test-"+UUID().uuidString)
  defer {try? FileManager.default.removeItem(at:root)}
  let scanner=Scanner(storageRoot:root)
  precondition(scanner.error == nil)
  let pages=(1...3).map{ScanPage(file:"Pages/\($0).jpg",original:"Originals/\($0).jpg")}
  var doc=ScanDocument();doc.pages=pages;try scanner.commit(doc)
  scanner.remove(pages[1]);precondition(scanner.document.pages.map(\.id)==[pages[0].id,pages[2].id])
  scanner.undo();precondition(scanner.document.pages.map(\.id)==pages.map(\.id),"Undo must restore original order")
  scanner.rotate(pages[0]);precondition(scanner.document.pages[0].rotation==90)
  try scanner.restore();precondition(scanner.document.pages[0].rotation==90,"Rotation must survive reload")
  let goodFolder=scanner.folder
  let manifest=try Data(contentsOf:goodFolder.appendingPathComponent("session.json"))
  let blocker=root.appendingPathComponent("not-a-folder")
  try Data("blocked".utf8).write(to:blocker)
  scanner.folder=blocker
  let before=scanner.document
  scanner.remove(pages[1]);precondition(scanner.document.pages.map(\.id)==before.pages.map(\.id))
  scanner.rotate(scanner.document.pages[0]);precondition(scanner.document.pages[0].rotation==before.pages[0].rotation)
  scanner.folder=goodFolder
  let after=try Data(contentsOf:goodFolder.appendingPathComponent("session.json"));precondition(after==manifest)
  scanner.error=nil
  scanner.remove(pages[0]);scanner.newDocument()
  precondition(scanner.deleting==nil,"Undo must not leak between documents")
  precondition(scanner.document.pages.isEmpty)
  precondition(FileManager.default.fileExists(atPath:goodFolder.appendingPathComponent("session.json").path))
  let second=scanner.folder
  scanner.root=blocker;scanner.newDocument()
  precondition(scanner.folder==second,"A failed new document must preserve the active folder")
  let black=CIImage(color:CIColor(red:0,green:0,blue:0)).cropped(to:CGRect(x:0,y:0,width:640,height:480))
  precondition(PaperDetector.detect(black,context:scanner.context,book:true)==nil)
  let sheet=CIImage(color:CIColor(red:1,green:1,blue:1)).cropped(to:CGRect(x:80,y:260,width:220,height:160)).composited(over:black)
  let corners=PaperDetector.detect(sheet,context:scanner.context,book:false)!
  precondition(abs(corners.tl.y-420.0/480)<0.02,"Detector must convert bitmap rows to bottom-left image coordinates")
  precondition(abs(corners.bl.y-260.0/480)<0.02,"Crop must preserve the sheet bottom edge")
  let brown=CIImage(color:CIColor(red:0.65,green:0.45,blue:0.42)).cropped(to:CGRect(x:0,y:0,width:640,height:480))
  let brownHasHands=try CaptureCheck.hasHands(brown,context:scanner.context)
  precondition(!brownHasHands,"Brown material alone must not be classified as a hand")
  var preflight=PreflightFeedbackGate()
  precondition(!preflight.observe("Hand",at:0))
  precondition(!preflight.observe("Hand",at:1),"Brief page-turn movement must not beep")
  precondition(preflight.observe("Hand",at:1.6),"Persistent obstruction must warn")
  precondition(!preflight.observe("Hand",at:8),"Persistent obstruction must not repeat its tone")
  precondition(!preflight.observe(nil,at:9))
  precondition(!preflight.observe("Hand",at:10))
  precondition(preflight.observe("Hand",at:12),"A later obstruction can warn again")
  var duplicateFeedback=DuplicateFeedbackGate()
  precondition(duplicateFeedback.notify(),"First duplicate must give feedback")
  for _ in 0..<20 {precondition(!duplicateFeedback.notify(),"Same duplicate must not repeat its tone")}
  duplicateFeedback.reset()
  precondition(duplicateFeedback.notify(),"A new saved page must allow the next duplicate alert")
  var gate=AutoCaptureGate()
  precondition(!gate.ready(at:0,moving:false,blocked:false,duplicate:false,hasPage:true))
  precondition(!gate.ready(at:0.5,moving:false,blocked:false,duplicate:false,hasPage:true))
  precondition(!gate.ready(at:0.9,moving:false,blocked:true,duplicate:false,hasPage:true),"A stationary hand must block capture")
  precondition(!gate.ready(at:1,moving:false,blocked:false,duplicate:false,hasPage:true))
  precondition(gate.ready(at:1.9,moving:false,blocked:false,duplicate:false,hasPage:true))
  gate.captured(at:1.9)
  precondition(!gate.ready(at:3.2,moving:false,blocked:false,duplicate:true,hasPage:true),"Same page must not rearm after cooldown")
  precondition(!gate.ready(at:4,moving:false,blocked:false,duplicate:false,hasPage:true))
  precondition(gate.ready(at:4.9,moving:false,blocked:false,duplicate:false,hasPage:true),"A clear changed page can capture")
  precondition(PageQuality.measure(black,context:scanner.context).reason?.contains("dark")==true)
  let white=CIImage(color:CIColor(red:1,green:1,blue:1)).cropped(to:black.extent)
  precondition(PageQuality.measure(white,context:scanner.context).reason==nil,"Blank white paper must not be labelled blurred")
  precondition(PageQuality(sharpness:5,contrast:100,whiteLevel:220).reason?.contains("blurred")==true)
  precondition(!PageQuality.touchesFrame(corners))
  var clipped=corners;clipped.tl.x=0
  precondition(PageQuality.touchesFrame(clipped))
  // Exercise the real reject and override flow in an isolated session.
  scanner.error=nil;scanner.busy=true
  scanner.process(black,originalData:nil)
  let deadline=Date().addingTimeInterval(5)
  while scanner.busy && Date()<deadline {RunLoop.main.run(until:Date().addingTimeInterval(0.01))}
  precondition(!scanner.busy && scanner.qualityWarning != nil)
  precondition(scanner.document.pages.isEmpty,"Rejected scans must stay out of the PDF manifest")
  precondition(scanner.rejectedURL.map{FileManager.default.fileExists(atPath:$0.path)}==true)
  scanner.keepRejected()
  let keepDeadline=Date().addingTimeInterval(5)
  while scanner.busy && Date()<keepDeadline {RunLoop.main.run(until:Date().addingTimeInterval(0.01))}
  precondition(scanner.document.pages.count==1,"Keep anyway must save the rejected photo")
  precondition(scanner.qualityWarning==nil)
  let still=[UInt8](repeating:128,count:64*48*4)
  var arm=still
  for y in 8..<16 {for x in 8..<16 {arm[(y*64+x)*4]=200}}
  precondition(CaptureCheck.motion(arm,still),"Small local movement must not be diluted by the background")
  precondition(!CaptureCheck.motion(still,still))
  print("PASS: undo order; persisted rotation; failed-write rollback; session isolation; new-document failure recovery; blank-frame rejection; asymmetric crop coordinates; hand and duplicate capture gates; local motion")
 }
}
