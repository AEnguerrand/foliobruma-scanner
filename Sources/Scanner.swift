import AppKit
import SwiftUI
import AVFoundation
import Vision
import PDFKit
import CoreImage
import UniformTypeIdentifiers
import ImageIO

struct ScanPage: Codable, Identifiable {
 var id: String = UUID().uuidString
 var file: String
 var original: String
 var rotation: Int = 0
}
struct ScanDocument: Codable {
 var title = "Family library"
 var pages: [ScanPage] = []
}
struct Quad {
 var tl: CGPoint; var tr: CGPoint; var br: CGPoint; var bl: CGPoint
 static let full = Quad(tl: .init(x:0,y:1),tr:.init(x:1,y:1),br:.init(x:1,y:0),bl:.init(x:0,y:0))
 var points: [CGPoint] { [tl,tr,br,bl] }
}

// Segmentation complements rectangle detection for ring binders and rounded pages.
enum PaperDetector {
 static func detect(_ image:CIImage,context:CIContext,book:Bool)->Quad? {
  let w=256,h=max(1,Int(256*image.extent.height/image.extent.width))
  let small=image.transformed(by:CGAffineTransform(scaleX:Double(w)/image.extent.width,y:Double(h)/image.extent.height))
  var rgba=[UInt8](repeating:0,count:w*h*4)
  context.render(small,toBitmap:&rgba,rowBytes:w*4,bounds:CGRect(x:0,y:0,width:w,height:h),format:.RGBA8,colorSpace:CGColorSpaceCreateDeviceRGB())
  var gray=[Int](repeating:0,count:w*h),hist=[Int](repeating:0,count:256)
  for i in 0..<w*h {gray[i]=(Int(rgba[i*4])*3+Int(rgba[i*4+1])*6+Int(rgba[i*4+2]))/10;hist[gray[i]]+=1}
  let total=Double(w*h),sum=hist.enumerated().reduce(0.0){$0+Double($1.offset*$1.element)}
  var sumB=0.0,weight=0.0,best=0.0,threshold=140
  for t in 0..<256 {weight+=Double(hist[t]);if weight==0{continue};let other=total-weight;if other==0{break};sumB+=Double(t*hist[t]);let delta=sumB/weight-(sum-sumB)/other;let score=weight*other*delta*delta;if score>best{best=score;threshold=t}}
  threshold=max(95,min(200,threshold))
  var seen=[Bool](repeating:false,count:w*h)
  var components:[(count:Int,box:CGRect)]=[]
  for start in 0..<w*h where !seen[start] && gray[start]>threshold {
   var todo=[start],head=0,minX=w,maxX=0,minY=h,maxY=0;seen[start]=true
   while head<todo.count {let p=todo[head];head+=1;let x=p%w,y=p/w;minX=min(minX,x);maxX=max(maxX,x);minY=min(minY,y);maxY=max(maxY,y)
    for (nx,ny) in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] where nx>=0 && nx<w && ny>=0 && ny<h {let n=ny*w+nx;if !seen[n] && gray[n]>threshold {seen[n]=true;todo.append(n)}}
   }
   if Double(todo.count)>total*0.035 {components.append((todo.count,CGRect(x:minX,y:minY,width:maxX-minX+1,height:maxY-minY+1)))}
  }
  components.sort{$0.count>$1.count}
  guard let first=components.first else{return nil}
  var box=first.box
  if book,components.count>1 {let b=components[1].box;let overlap=max(0,min(box.maxY,b.maxY)-max(box.minY,b.minY));let gap=max(0,max(box.minX,b.minX)-min(box.maxX,b.maxX));if overlap>min(box.height,b.height)*0.5 && gap<Double(w)*0.15 {box=box.union(b)}}
  guard box.width>Double(w)*0.2,box.height>Double(h)*0.25,box.width*box.height<Double(w*h)*0.98 else{return nil}
  let l=max(0,(box.minX-1)/Double(w)),r=min(1,(box.maxX+1)/Double(w)),b=max(0,1-(box.maxY+1)/Double(h)),t=min(1,1-(box.minY-1)/Double(h))
  return Quad(tl:CGPoint(x:l,y:t),tr:CGPoint(x:r,y:t),br:CGPoint(x:r,y:b),bl:CGPoint(x:l,y:b))
 }
}

// Automatic capture gates use elapsed time, not the number of camera callbacks.
struct AutoCaptureGate {
 var clearSince:Double?
 var cooldownUntil=0.0
 mutating func reset(){clearSince=nil}
 mutating func captured(at now:Double){clearSince=nil;cooldownUntil=now+0.8}
 mutating func ready(at now:Double,moving:Bool,blocked:Bool,duplicate:Bool,hasPage:Bool)->Bool {
  guard !moving,!blocked,!duplicate,hasPage,now>=cooldownUntil else {clearSince=nil;return false}
  guard let start=clearSince else {clearSince=now;return false}
  return now-start>=0.55
 }
}
struct PreflightFeedbackGate {
 var reason:String?
 var since=0.0
 var notified=false
 mutating func observe(_ value:String?,at now:Double)->Bool {
  guard let value=value else {reason=nil;notified=false;return false}
  if reason != value {reason=value;since=now;notified=false}
  guard !notified,now-since>=1.5 else{return false}
  notified=true;return true
 }
}
struct DuplicateFeedbackGate {
 var notified=false
 mutating func notify()->Bool {guard !notified else{return false};notified=true;return true}
 mutating func reset(){notified=false}
}
enum CaptureCheck {
 static func reduced(_ image:CIImage)->CIImage {image.transformed(by:CGAffineTransform(scaleX:640/image.extent.width,y:640/image.extent.width))}
 static func fingerprint(_ image:CIImage)throws->VNFeaturePrintObservation? {
  let r=VNGenerateImageFeaturePrintRequest();r.revision=VNGenerateImageFeaturePrintRequestRevision2
  try VNImageRequestHandler(ciImage:reduced(image),options:[:]).perform([r]);return r.results?.first
 }
 static func duplicate(_ print:VNFeaturePrintObservation,of recent:[VNFeaturePrintObservation])->Bool {
  recent.contains {other in var distance:Float=1;do{try print.computeDistance(&distance,to:other);return distance<0.18}catch{return false}}
 }
 static func hasHands(_ image:CIImage,context:CIContext)throws->Bool {
  let frame=reduced(image)
  // Overhead cameras see hands from every side; normalize orientation for the model.
  for orientation in [CGImagePropertyOrientation.up,.left,.right,.down] {
   let r=VNDetectHumanHandPoseRequest();r.maximumHandCount=2
   try VNImageRequestHandler(ciImage:frame,orientation:orientation,options:[:]).perform([r])
   if !(r.results ?? []).isEmpty{return true}
  }
  // Inspect overlapping regions: clipped hands can be too small in the full view.
  for y in [0.0,0.4] {
   let region=CGRect(x:image.extent.minX,y:image.extent.minY+image.extent.height*y,width:image.extent.width,height:image.extent.height*0.6)
   let crop=image.cropped(to:region).transformed(by:CGAffineTransform(translationX:-region.minX,y:-region.minY))
   let check=VNDetectHumanHandPoseRequest();check.maximumHandCount=2
   try VNImageRequestHandler(ciImage:reduced(crop),options:[:]).perform([check])
   if !(check.results ?? []).isEmpty{return true}
  }
  return false
 }
 static func motion(_ a:[UInt8],_ b:[UInt8])->Bool {
  guard a.count==b.count,a.count==64*48*4 else{return true}
  // Check small regions, so an arm is not diluted by the unchanged background.
  for by in stride(from:0,to:48,by:8){for bx in stride(from:0,to:64,by:8){var total=0.0
   for y in by..<by+8 {for x in bx..<bx+8 {let i=(y*64+x)*4;total+=abs(Double(a[i])-Double(b[i]))}}
   if total/64>9{return true}
  }}
  return false
 }
}

struct PageQuality {
 let sharpness:Double
 let contrast:Double
 let whiteLevel:Double
 var reason:String? {
  if whiteLevel<55 {return "Too dark · Add light and rescan"}
  if contrast>35 && sharpness<12 {return "Scan looks blurred · Hold the page still and rescan"}
  return nil
 }
 static func touchesFrame(_ q:Quad)->Bool {q.points.contains{$0.x<=0.003 || $0.x>=0.997 || $0.y<=0.003 || $0.y>=0.997}}
 static func measure(_ image:CIImage,context:CIContext)->PageQuality {
  let w=512,h=max(8,Int(512*image.extent.height/image.extent.width))
  let origin=image.transformed(by:CGAffineTransform(translationX:-image.extent.minX,y:-image.extent.minY))
  let small=origin.transformed(by:CGAffineTransform(scaleX:Double(w)/image.extent.width,y:Double(h)/image.extent.height))
  var rgba=[UInt8](repeating:0,count:w*h*4)
  context.render(small,toBitmap:&rgba,rowBytes:w*4,bounds:CGRect(x:0,y:0,width:w,height:h),format:.RGBA8,colorSpace:CGColorSpaceCreateDeviceRGB())
  var gray=[Double](repeating:0,count:w*h)
  for i in 0..<w*h {gray[i]=(Double(rgba[i*4])*3+Double(rgba[i*4+1])*6+Double(rgba[i*4+2]))/10}
  var total=0.0,count=0,levels:[Double]=[]
  for y in max(1,h/20)..<min(h-1,h*19/20) {for x in w/20..<w*19/20 {let i=y*w+x;let lap=gray[i-1]+gray[i+1]+gray[i-w]+gray[i+w]-4*gray[i];total+=lap*lap;count+=1;levels.append(gray[i])}}
  levels.sort();let low=levels[levels.count/20],high=levels[levels.count*19/20]
  return PageQuality(sharpness:total/Double(count),contrast:high-low,whiteLevel:high)
 }
}

final class Scanner: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
 @Published var devices: [AVCaptureDevice] = []
 @Published var deviceID = ""
 @Published var connected = false
 @Published var status = "Connect your scanner to begin"
 @Published var error: String? { didSet { if error != nil { captureSaved=false; if soundEnabled && tracksActiveSession { NSSound(named:"Basso")?.play() } } } }
 @Published var book = true
 @Published var split = true
 @Published var autoCrop = true
 @Published var autoCapture = false {didSet {duplicateFeedback.reset();duplicateWarning=false;updatePreflight(nil);let enabled=autoCapture;queue.async{self.autoEnabled=enabled;self.gate.reset();self.heldFrame=nil}}}
 @Published var soundEnabled = true
 @Published var preflightWarning:String?
 var preflightFeedback=PreflightFeedbackGate()
 @Published var duplicateWarning=false
 var duplicateFeedback=DuplicateFeedbackGate()
 @Published var captureSaved = false
 @Published var qualityWarning:String?
 @Published var rejectedURL:URL?
 var feedbackID = UUID()
 @Published var busy = false
 @Published var quad: Quad?
 @Published var selected: String?
 @Published var document = ScanDocument()
 @Published var folder: URL
 @Published var resolution = ""
 @Published var divider = 0.5
 @Published var lastPDF: URL?
 let session = AVCaptureSession()
 let queue = DispatchQueue(label:"foliobruma.camera")
 let context = CIContext(options:[.cacheIntermediates:false])
 let photoOutput = AVCapturePhotoOutput()
 let videoOutput = AVCaptureVideoDataOutput()
 var input: AVCaptureDeviceInput?
 var latest: CIImage?
 var lastTick = 0.0
 var previous: [UInt8]?
 var autoEnabled=false
 var captureInFlight=false
 var heldFrame:[UInt8]?
 var heldReason=""
 var heldPreflightWarning:String?
 var gate = AutoCaptureGate()
 var recentPrints:[VNFeaturePrintObservation]=[]

 var captureOptions: (quad: Quad?, split: Bool, divider: Double, automatic:Bool)?
 @Published var deleting: (page: ScanPage, index: Int)?
 let tracksActiveSession: Bool
 var root: URL
 init(storageRoot: URL? = nil) {
  let base = storageRoot ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Sovenelia Scanner",isDirectory:true)
  root=base;tracksActiveSession = storageRoot == nil
  let saved = storageRoot == nil ? UserDefaults.standard.string(forKey:"activeSession") : nil
  folder=saved.map{URL(fileURLWithPath:$0)} ?? base.appendingPathComponent("Sessions/"+UUID().uuidString,isDirectory:true)
  super.init()
  do {try prepareFolder();try restore()} catch {self.error=error.localizedDescription}
  if storageRoot == nil {devices=AVCaptureDevice.DiscoverySession(deviceTypes:[.external,.builtInWideAngleCamera],mediaType:.video,position:.unspecified).devices}
  seedRecentPages()
  deviceID=devices.first(where:{$0.localizedName.localizedCaseInsensitiveContains("IRIS")})?.uniqueID ?? devices.first?.uniqueID ?? ""
 }
 func prepareFolder() throws {
  try FileManager.default.createDirectory(at:folder.appendingPathComponent("Originals"),withIntermediateDirectories:true)
  try FileManager.default.createDirectory(at:folder.appendingPathComponent("Pages"),withIntermediateDirectories:true)
  if tracksActiveSession {UserDefaults.standard.set(folder.path,forKey:"activeSession")}
 }
 func restore() throws {let u=folder.appendingPathComponent("session.json");if FileManager.default.fileExists(atPath:u.path){document=try JSONDecoder().decode(ScanDocument.self,from:Data(contentsOf:u))}}
 func commit(_ next: ScanDocument) throws {
  try JSONEncoder().encode(next).write(to:folder.appendingPathComponent("session.json"),options:.atomic)
  document=next
 }
 func persist() throws {try commit(document)}
 func report(_ message: String) {DispatchQueue.main.async {self.status=message}}
 func connect() {
  guard !busy else{return}
  autoCapture=false;status="Requesting camera access…"
  AVCaptureDevice.requestAccess(for:.video){allowed in
   guard allowed else {DispatchQueue.main.async {self.error="Camera access is off. Enable Foliobruma Scanner in System Settings → Privacy & Security → Camera."};return}
   self.report("Opening scanner…");self.queue.async {self.configure()}
  }
 }
 func configure() {
  guard let device=devices.first(where:{$0.uniqueID==deviceID}) else {report("Select a camera first");return}
  session.stopRunning();session.beginConfiguration();var configurationOpen=true
  if let old=input {session.removeInput(old)}
  do {
   let next=try AVCaptureDeviceInput(device:device)
   guard session.canAddInput(next) else {throw NSError(domain:"Scanner",code:1,userInfo:[NSLocalizedDescriptionKey:"This camera cannot be opened."])}
   session.addInput(next);input=next
   if session.canSetSessionPreset(.photo) {session.sessionPreset = .photo} else {session.sessionPreset = .high}
   if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {session.addOutput(photoOutput)}
   if !session.outputs.contains(videoOutput),session.canAddOutput(videoOutput) {
    videoOutput.alwaysDiscardsLateVideoFrames=true
    videoOutput.videoSettings=[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]
    videoOutput.setSampleBufferDelegate(self,queue:queue);session.addOutput(videoOutput)
   }
   try device.lockForConfiguration()
   if let best=device.formats.max(by:{a,b in let x=CMVideoFormatDescriptionGetDimensions(a.formatDescription),y=CMVideoFormatDescriptionGetDimensions(b.formatDescription);return Int(x.width)*Int(x.height)<Int(y.width)*Int(y.height)}) {
    device.activeFormat=best
    if let dims=best.supportedMaxPhotoDimensions.max(by:{Int($0.width)*Int($0.height)<Int($1.width)*Int($1.height)}) {photoOutput.maxPhotoDimensions=dims}
   }
   device.unlockForConfiguration()
   session.commitConfiguration();configurationOpen=false;session.startRunning()
   try device.lockForConfiguration()
   if let best=device.formats.max(by:{a,b in let x=CMVideoFormatDescriptionGetDimensions(a.formatDescription),y=CMVideoFormatDescriptionGetDimensions(b.formatDescription);return Int(x.width)*Int(x.height)<Int(y.width)*Int(y.height)}) {
    device.activeFormat=best
    let fps=best.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 8
    device.activeVideoMinFrameDuration=CMTime(value:1,timescale:Int32(fps.rounded()))
    device.activeVideoMaxFrameDuration=device.activeVideoMinFrameDuration
   }
   device.unlockForConfiguration()
   let dims=CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
   DispatchQueue.main.async {self.connected=true;self.resolution="\(dims.width) × \(dims.height)";self.status="Ready to capture";self.quad=nil}
  } catch {if configurationOpen {session.commitConfiguration()};DispatchQueue.main.async {self.connected=false;self.error=error.localizedDescription}}
 }
 func captureOutput(_ output:AVCaptureOutput,didOutput sample:CMSampleBuffer,from connection:AVCaptureConnection) {
  guard let buffer=CMSampleBufferGetImageBuffer(sample) else{return}
  latest=CIImage(cvPixelBuffer:buffer)
  let now=Date.timeIntervalSinceReferenceDate
  guard now-lastTick > 0.18, let image=latest else{return};lastTick=now
  let small=image.transformed(by:CGAffineTransform(scaleX:64/image.extent.width,y:48/image.extent.height))
  var bytes=[UInt8](repeating:0,count:64*48*4)
  context.render(small,toBitmap:&bytes,rowBytes:64*4,bounds:CGRect(x:0,y:0,width:64,height:48),format:.RGBA8,colorSpace:CGColorSpaceCreateDeviceRGB())
  let moving=previous.map{CaptureCheck.motion(bytes,$0)} ?? true
  previous=bytes
  var detected: Quad? = PaperDetector.detect(image,context:context,book: self.book)
  let request=VNDetectRectanglesRequest()
  request.maximumObservations=8;request.minimumConfidence=0.65;request.minimumAspectRatio=0.25;request.maximumAspectRatio=1;request.minimumSize=0.18;request.quadratureTolerance=35
  do {
   let reduced=image.transformed(by:CGAffineTransform(scaleX:1000/image.extent.width,y:1000/image.extent.width))
   try VNImageRequestHandler(ciImage:reduced,options:[:]).perform([request])
   if let r=request.results?.max(by:{$0.boundingBox.width*$0.boundingBox.height < $1.boundingBox.width*$1.boundingBox.height}) {
    let area=r.boundingBox.width*r.boundingBox.height
    let maskArea=detected.map{abs(($0.tr.x-$0.tl.x)*($0.tl.y-$0.bl.y))} ?? 0
    if area >= maskArea*0.85 {detected=Quad(tl:r.topLeft,tr:r.topRight,br:r.bottomRight,bl:r.bottomLeft)}
   }
  }catch{}
  func display(_ message:String) {
   DispatchQueue.main.async {if self.autoCrop {self.quad=detected};if self.autoCapture && !self.busy {self.status=message}}
  }
  guard autoEnabled,!captureInFlight else {display("Ready to capture");return}
  if let held=heldFrame {
   if !CaptureCheck.motion(bytes,held) {display(heldReason);let warning=heldPreflightWarning;DispatchQueue.main.async{self.updatePreflight(warning)};return}
   heldFrame=nil;heldPreflightWarning=nil;gate.reset()
  }
  let warning = detected == nil && !moving ? "Page edges not found · Place the page inside the view":nil
  DispatchQueue.main.async{self.updatePreflight(warning)}
  guard gate.ready(at:now,moving:moving,blocked:false,duplicate:false,hasPage:detected != nil) else {
   display(detected == nil ? "Looking for page edges…" : (moving ? "Hold the page still…" : "Checking the next page…"));return
  }
  do {
   let hands=try CaptureCheck.hasHands(image,context:context)
   guard !hands else {heldFrame=bytes;heldPreflightWarning="Hand in view · Move your hands away";DispatchQueue.main.async{self.updatePreflight("Hand in view · Move your hands away")};heldReason="Move your hands away…";gate.reset();display(heldReason);return}
   guard let print=try CaptureCheck.fingerprint(image) else {gate.reset();display("Could not check the page · Try Capture");return}
   if CaptureCheck.duplicate(print,of:recentPrints) {heldFrame=bytes;heldReason="Page already saved · Turn the page";gate.reset();display(heldReason);DispatchQueue.main.async{self.showDuplicate()};return}
  } catch {gate.reset();display("Could not check the page · Try Capture");return}
  gate.captured(at:Date.timeIntervalSinceReferenceDate);captureInFlight=true
  DispatchQueue.main.async {
   if self.autoCrop {self.quad=detected}
   if self.autoCapture && !self.busy {self.capture(automatic:true)}
   else {self.queue.async{self.captureInFlight=false;self.gate.reset()}}
  }
 }
 func seedRecentPages() {
  let base=folder
  var names:[String]=[]
  for p in document.pages.reversed() where !names.contains(p.original) {names.append(p.original);if names.count==4 {break}}
  queue.async {self.gate=AutoCaptureGate();self.previous=nil;self.heldFrame=nil;self.recentPrints=names.compactMap {name in guard let image=CIImage(contentsOf:base.appendingPathComponent(name)) else{return nil};return try? CaptureCheck.fingerprint(image)}}
 }
 func capture(){capture(automatic:false)}
 func capture(automatic:Bool) {
  guard connected,!busy else{if automatic {queue.async{self.captureInFlight=false;self.gate.reset()}};return}
  if autoCrop && quad == nil {if automatic {queue.async{self.captureInFlight=false;self.gate.reset()}};status="No page edges found. Turn off Auto crop to capture the full frame.";return}
  updatePreflight(nil)
  busy=true;selected=nil;captureSaved=false;duplicateWarning=false;qualityWarning=nil;rejectedURL=nil;status="Capturing… Hold still"
  captureOptions=(autoCrop ? quad:nil,book && split,divider,automatic)
  queue.async {
   self.captureInFlight=true;self.gate.captured(at:Date.timeIntervalSinceReferenceDate)
   if self.session.outputs.contains(self.photoOutput),!self.photoOutput.availablePhotoCodecTypes.isEmpty {
    let settings=AVCapturePhotoSettings(format:[AVVideoCodecKey:AVVideoCodecType.jpeg]);settings.maxPhotoDimensions=self.input!.device.activeFormat.supportedMaxPhotoDimensions.first ?? self.photoOutput.maxPhotoDimensions
    self.photoOutput.capturePhoto(with:settings,delegate:self)
   } else if let image=self.latest {self.process(image,originalData:nil)} else {self.captureInFlight=false;DispatchQueue.main.async {self.busy=false;self.error="The camera has not delivered an image yet."}}
  }
 }
 func photoOutput(_ output:AVCapturePhotoOutput,didFinishProcessingPhoto photo:AVCapturePhoto,error:Error?) {
  if let data=photo.fileDataRepresentation(),let image=CIImage(data:data) {queue.async {self.process(image,originalData:data)}}
  else {queue.async {if let image=self.latest {self.process(image,originalData:nil)} else {self.captureInFlight=false;DispatchQueue.main.async {self.busy=false;self.error=error?.localizedDescription ?? "Capture failed"}}}}
 }
 func process(_ source:CIImage,originalData:Data?,overrideQuality:Bool=false) {
  report("Checking scan quality…")
  let options=captureOptions ?? (nil,false,0.5,false)
  do {
   let print=try? CaptureCheck.fingerprint(source)
   if !overrideQuality {
    if try CaptureCheck.hasHands(source,context:context) {try rejectCapture("Hand in the scan · Move your hands away",source:source,data:originalData);return}
    if options.automatic {
     guard let print=print else {try rejectCapture("Could not check this scan · Try again",source:source,data:originalData);return}
     if CaptureCheck.duplicate(print,of:recentPrints) {
      captureInFlight=false;gate.reset();heldFrame=previous;heldReason="Page already saved · Turn the page"
      DispatchQueue.main.async{self.busy=false;self.showDuplicate()};return
     }
    }
    if options.quad != nil,let edges=PaperDetector.detect(source,context:context,book:options.split),PageQuality.touchesFrame(edges) {
     try rejectCapture("Page may be cut off · Move it inside the camera view",source:source,data:originalData);return
    }
   }
   let id=UUID().uuidString,original="Originals/\(id).jpg"
   let data=originalData ?? context.jpegRepresentation(of:source,colorSpace:CGColorSpaceCreateDeviceRGB(),options:[:])!
   var output=source
   if let q=options.quad {
    func v(_ p:CGPoint)->CIVector {CIVector(x:source.extent.minX+p.x*source.extent.width,y:source.extent.minY+p.y*source.extent.height)}
    output=source.applyingFilter("CIPerspectiveCorrection",parameters:["inputTopLeft":v(q.tl),"inputTopRight":v(q.tr),"inputBottomRight":v(q.br),"inputBottomLeft":v(q.bl)])
   }
   if !overrideQuality,let reason=PageQuality.measure(output,context:context).reason {
    try rejectCapture(reason,source:source,data:originalData);return
   }
   try data.write(to:folder.appendingPathComponent(original),options:.atomic)
   var results:[ScanPage]=[]
   for i in 0..<(options.split ? 2:1) {
    var area=output.extent
    if options.split {let left=area.width*options.divider;if i==0 {area.size.width=left}else{area.origin.x+=left;area.size.width-=left}}
    guard let cg=context.createCGImage(output,from:area) else {throw NSError(domain:"Scanner",code:2,userInfo:[NSLocalizedDescriptionKey:"Image processing failed"])}
    let rep=NSBitmapImageRep(cgImage:cg)
    guard let jpeg=rep.representation(using:.jpeg,properties:[.compressionFactor:0.96]) else {throw NSError(domain:"Scanner",code:3)}
    let file="Pages/\(id)-\(i+1).jpg"
    try jpeg.write(to:folder.appendingPathComponent(file),options:.atomic)
    results.append(ScanPage(file:file,original:original))
   }
   DispatchQueue.main.async {
    var next=self.document
    next.pages+=results
    var saved=false
    do {try self.commit(next);saved=true;self.status="\(results.count) \(results.count==1 ? "page":"pages") saved · Turn the page";self.confirmCapture();if let print=print {self.queue.async{self.recentPrints.append(print);self.recentPrints=Array(self.recentPrints.suffix(4))}}}catch{self.error="Could not save session: \(error.localizedDescription)"}
    let committed=saved
    self.queue.async{self.captureInFlight=false;self.gate.reset();self.heldFrame=committed ? self.previous:nil;self.heldReason="Page already saved · Turn the page"}
    self.busy=false;self.resolution="\(Int(source.extent.width)) × \(Int(source.extent.height))"
   }
  } catch {captureInFlight=false;DispatchQueue.main.async {self.busy=false;self.error=error.localizedDescription}}
 }
 func rejectCapture(_ reason:String,source:CIImage,data:Data?) throws {
  let directory=folder.appendingPathComponent("Rejected",isDirectory:true)
  try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
  let url=directory.appendingPathComponent(UUID().uuidString+".jpg")
  guard let bytes=data ?? context.jpegRepresentation(of:source,colorSpace:CGColorSpaceCreateDeviceRGB(),options:[:]) else {throw NSError(domain:"Scanner",code:5)}
  try bytes.write(to:url,options:.atomic)
  captureInFlight=false;gate.reset();heldFrame=previous;heldReason="Rescan · "+reason
  DispatchQueue.main.async {
   self.busy=false;self.captureSaved=false;self.duplicateWarning=false;self.qualityWarning=reason;self.rejectedURL=url;self.status="Rescan needed"
   if self.soundEnabled && self.tracksActiveSession {NSSound(named:"Basso")?.play()}
  }
 }
 func keepRejected() {
  guard !busy,let url=rejectedURL else{return}
  busy=true;qualityWarning=nil;rejectedURL=nil
  queue.async {
   self.captureInFlight=true
   do {let data=try Data(contentsOf:url);guard let image=CIImage(data:data) else{throw NSError(domain:"Scanner",code:6)};self.process(image,originalData:data,overrideQuality:true)}
   catch {self.captureInFlight=false;DispatchQueue.main.async{self.busy=false;self.error=error.localizedDescription}}
  }
 }
 func updatePreflight(_ reason:String?) {
  guard autoCapture else {preflightWarning=nil;_ = preflightFeedback.observe(nil,at:0);return}
  if preflightFeedback.observe(reason,at:Date.timeIntervalSinceReferenceDate) {
   preflightWarning=reason
   if soundEnabled && tracksActiveSession {NSSound(named:"Pop")?.play()}
  } else if reason == nil {preflightWarning=nil}
 }
 func showDuplicate() {
  status="Already scanned · Turn the page"
  duplicateWarning=true
  if duplicateFeedback.notify(),soundEnabled,tracksActiveSession {NSSound(named:"Tink")?.play()}
 }
 func confirmCapture() {
  duplicateWarning=false;duplicateFeedback.reset()
  captureSaved=true
  let id=UUID();feedbackID=id
  if soundEnabled && tracksActiveSession { NSSound(named:"Glass")?.play() }
  DispatchQueue.main.asyncAfter(deadline:.now()+1.0) {if self.feedbackID==id {self.captureSaved=false}}
 }
 func image(_ p:ScanPage)->NSImage? {NSImage(contentsOf:folder.appendingPathComponent(p.file))}
 func rotate(_ page:ScanPage) {
  guard !busy,let i=document.pages.firstIndex(where:{$0.id==page.id}) else{return}
  var next=document;next.pages[i].rotation=(page.rotation+90)%360
  do {try commit(next)}catch{self.error=error.localizedDescription}
 }
 func remove(_ page:ScanPage) {
  guard !busy,let index=document.pages.firstIndex(where:{$0.id==page.id}) else{return}
  var next=document;next.pages.remove(at:index)
  do {try commit(next);deleting=(page,index);selected=nil;status="Page removed · Undo available"}catch{self.error=error.localizedDescription}
 }
 func undo() {
  guard !busy,let removed=deleting else{return}
  var next=document;next.pages.insert(removed.page,at:min(removed.index,next.pages.count))
  do{try commit(next);deleting=nil;status="Page restored"}catch{self.error=error.localizedDescription}
 }
 func newDocument() {
  guard !busy else{return};autoCapture=false
  do {
   try persist()
   let nextFolder=root.appendingPathComponent("Sessions/"+UUID().uuidString)
   try FileManager.default.createDirectory(at:nextFolder.appendingPathComponent("Originals"),withIntermediateDirectories:true)
   try FileManager.default.createDirectory(at:nextFolder.appendingPathComponent("Pages"),withIntermediateDirectories:true)
   let next=ScanDocument()
   try JSONEncoder().encode(next).write(to:nextFolder.appendingPathComponent("session.json"),options:.atomic)
   folder=nextFolder;document=next;selected=nil;lastPDF=nil;deleting=nil;duplicateWarning=false;duplicateFeedback.reset();qualityWarning=nil;rejectedURL=nil
   if tracksActiveSession {UserDefaults.standard.set(folder.path,forKey:"activeSession")}
   seedRecentPages()
   status="New document · Previous session kept on disk"
  }catch{self.error=error.localizedDescription}
 }
 func openSession() {
  guard !busy else{return};autoCapture=false
  let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false;panel.directoryURL=root.appendingPathComponent("Sessions");panel.message="Choose a Foliobruma session folder."
  if panel.runModal() == .OK,let u=panel.url {
   do {let restored=try JSONDecoder().decode(ScanDocument.self,from:Data(contentsOf:u.appendingPathComponent("session.json")));folder=u;document=restored;selected=nil;deleting=nil;lastPDF=nil;qualityWarning=nil;rejectedURL=nil;UserDefaults.standard.set(u.path,forKey:"activeSession");status="Session restored";seedRecentPages()}catch{self.error="This folder does not contain a valid Foliobruma session."}
  }
 }
 func exportPDF() {
  guard !document.pages.isEmpty,!busy else{return};autoCapture=false
  let panel=NSSavePanel();panel.allowedContentTypes=[.pdf];panel.nameFieldStringValue=document.title+".pdf";panel.canCreateDirectories=true
  guard panel.runModal() == .OK,let destination=panel.url else{return}
  busy=true;status="Creating PDF…"
  let snapshot=document.pages,base=folder
  DispatchQueue.global(qos:.userInitiated).async {
   let pdf=PDFDocument()
   for p in snapshot {guard let image=NSImage(contentsOf:base.appendingPathComponent(p.file)),let page=PDFPage(image:image) else{DispatchQueue.main.async {self.busy=false;self.error="A page image is missing. PDF export stopped."};return};page.rotation=p.rotation;pdf.insert(page,at:pdf.pageCount)}
   do {guard let data=pdf.dataRepresentation() else {throw NSError(domain:"Scanner",code:4)};try data.write(to:destination,options:.atomic)
    DispatchQueue.main.async {self.busy=false;self.lastPDF=destination;self.status="PDF saved · \(snapshot.count) pages"}
   }catch{DispatchQueue.main.async {self.busy=false;self.error=error.localizedDescription}}
  }
 }
}

struct CameraView:NSViewRepresentable {
 let session:AVCaptureSession
 func makeNSView(context:Context)->NSView {let view=PreviewView();view.layer=AVCaptureVideoPreviewLayer(session:session);view.wantsLayer=true;(view.layer as? AVCaptureVideoPreviewLayer)?.videoGravity = .resizeAspect;return view}
 func updateNSView(_ nsView:NSView,context:Context){}
}
final class PreviewView:NSView {override func layout(){super.layout();layer?.frame=bounds}}
struct ContentView:View {
 @StateObject var model=Scanner()
 @State var rename=false
 let gold=Color(red:1,green:0.74,blue:0.27)
 var body:some View {
  VStack(spacing:0) {
   HStack(spacing:22) {
    Label("Foliobruma Scanner",systemImage:"camera").font(.headline)
    Spacer()
    Menu(model.document.title){Button("Rename document…"){rename=true};Button("New document",action:model.newDocument);Button("Open saved session…",action:model.openSession)}.frame(maxWidth:210)
    Picker("Mode",selection:$model.book){Label("Book",systemImage:"book").tag(true);Label("Letters",systemImage:"envelope").tag(false)}.pickerStyle(.segmented).frame(width:200)
    Picker("Camera",selection:$model.deviceID){ForEach(model.devices,id:\.uniqueID){Text($0.localizedName).tag($0.uniqueID)}}.labelsHidden().frame(width:220).onChange(of:model.deviceID){ if model.connected {model.connect()}}
    Button(action:model.exportPDF){Label("Save PDF",systemImage:"doc")}.disabled(model.document.pages.isEmpty || model.busy)
   }.padding(18).background(Color(white:0.13))
   GeometryReader {g in
    ZStack {
     Color.black
     if let id=model.selected,let page=model.document.pages.first(where:{$0.id==id}),let image=model.image(page) {
      Image(nsImage:image).resizable().scaledToFit().rotationEffect(.degrees(Double(page.rotation))).padding(25)
      VStack {Spacer();HStack {Button("Rotate"){model.rotate(page)};Button("Remove"){model.remove(page)};Button("Back to camera"){model.selected=nil}}.padding().background(.ultraThinMaterial).cornerRadius(10).padding()}
     } else {
      CameraView(session:model.session)
      if model.connected,model.autoCrop,let q=model.quad {
       let ratio = dimensionsRatio(model.resolution)
       let w=min(g.size.width,g.size.height*ratio),h=w/ratio,ox=(g.size.width-w)/2,oy=(g.size.height-h)/2
       Path {p in let a=q.points.map{CGPoint(x:ox+$0.x*w,y:oy+(1-$0.y)*h)};p.move(to:a[0]);for v in a.dropFirst(){p.addLine(to:v)};p.closeSubpath()
        if model.book && model.split {let t=model.divider;p.move(to:CGPoint(x:ox+(q.tl.x+(q.tr.x-q.tl.x)*t)*w,y:oy+(1-(q.tl.y+(q.tr.y-q.tl.y)*t))*h));p.addLine(to:CGPoint(x:ox+(q.bl.x+(q.br.x-q.bl.x)*t)*w,y:oy+(1-(q.bl.y+(q.br.y-q.bl.y)*t))*h))}
       }.stroke(gold,lineWidth:2).allowsHitTesting(false)
      }
      if !model.connected {VStack(spacing:20){Image(systemName:"camera").font(.system(size:48)).foregroundColor(gold);Text("Your archive starts here").font(.title2);Text("Connect your scanner and place a page under the camera.").foregroundColor(.secondary);Button("Connect scanner",action:model.connect).buttonStyle(.borderedProminent)}}
     }
     if let reason=model.qualityWarning {
      VStack(spacing:12){Label("Rescan needed",systemImage:"exclamationmark.triangle.fill").font(.title.bold());Text(reason).font(.headline);Text("This photo is kept separately and is not in your PDF.").font(.callout);Button("Keep this scan anyway",action:model.keepRejected).disabled(model.busy)}.foregroundColor(.white).padding(24).background(Color(red:0.48,green:0.10,blue:0.08).opacity(0.96)).cornerRadius(16)
     }
     if let warning=model.preflightWarning,model.qualityWarning == nil {
      VStack{Spacer();Label(warning,systemImage:"hand.raised.fill").font(.headline).foregroundColor(.black).padding(14).background(gold.opacity(0.96)).cornerRadius(10).padding(.bottom,18)}.allowsHitTesting(false)
     }
     if model.duplicateWarning && model.qualityWarning == nil && model.preflightWarning == nil {
      VStack(spacing:12){Label("Already scanned",systemImage:"doc.on.doc.fill").font(.title.bold());Text("Turn the page. No extra copy was saved.").font(.headline)}.foregroundColor(.black).padding(24).background(gold.opacity(0.96)).cornerRadius(16).allowsHitTesting(false)
     }
     if model.captureSaved {
      Rectangle().stroke(Color.green,lineWidth:8).allowsHitTesting(false)
      VStack(spacing:12){Image(systemName:"checkmark.circle.fill").font(.system(size:60));Text("Saved — turn the page").font(.title.bold())}.foregroundColor(.white).padding(28).background(Color(red:0.08,green:0.32,blue:0.18).opacity(0.96)).cornerRadius(18).allowsHitTesting(false)
     }
     VStack{Text(model.status).font(.callout).padding(10).background(Color.black.opacity(0.8)).cornerRadius(8).padding(.top,16);Spacer()}.allowsHitTesting(false)
    }
   }.frame(minHeight:280)
   ScrollView(.horizontal){HStack(spacing:22){if model.document.pages.isEmpty {Label("Captured pages will appear here",systemImage:"book").foregroundColor(.secondary).padding(30)};ForEach(Array(model.document.pages.enumerated()),id:\.element.id){index,p in Button{model.selected=p.id}label:{VStack(spacing:6){if let img=model.image(p){Image(nsImage:img).resizable().scaledToFit().frame(width:92,height:88).rotationEffect(.degrees(Double(p.rotation)))};Text("\(index+1)").font(.caption)}.padding(7).background(model.selected==p.id ? gold.opacity(0.15):Color.clear).cornerRadius(5)}.buttonStyle(.plain)};Spacer()}.padding(.horizontal,30).padding(.vertical,10)}.frame(height:132).background(Color(white:0.12))
   HStack(spacing:20){
    Button {model.selected=nil;model.autoCapture.toggle();}label:{Label(model.autoCapture ? "Pause auto capture":"Start auto capture",systemImage:model.autoCapture ? "pause.fill":"play.fill").fontWeight(.semibold).padding(10)}.buttonStyle(.borderedProminent).disabled(!model.connected || model.busy)
    Button(action:model.capture){Label(model.busy ? "Working…":"Capture",systemImage:"camera.fill").padding(10)}.keyboardShortcut(.space,modifiers:[]).disabled(!model.connected || model.busy)
    if model.book {Toggle("Split pages",isOn:$model.split).toggleStyle(.switch)}
    Toggle("Auto crop",isOn:$model.autoCrop).toggleStyle(.switch)
    Toggle(isOn:$model.soundEnabled){Image(systemName:model.soundEnabled ? "speaker.wave.2.fill":"speaker.slash.fill")}.toggleStyle(.switch).help("Play success, duplicate, pre-capture warning, and rescan sounds").accessibilityLabel("Capture sounds")
    if model.book && model.split {HStack{Text("Spine").foregroundColor(.secondary);Slider(value:$model.divider,in:0.3...0.7).frame(width:90)}}
   }.padding(20)
   Divider()
   HStack(spacing:20){Label(model.connected ? "\(model.resolution) · Connected":"Local only",systemImage:model.connected ? "camera":"lock");Text("\(model.document.pages.count) pages");Spacer();Button("Undo removal",action:model.undo).disabled(model.deleting==nil);Button{NSWorkspace.shared.open(model.folder)}label:{Label("Originals & session",systemImage:"folder")};if let pdf=model.lastPDF {Button("Open PDF"){NSWorkspace.shared.open(pdf)}}}.font(.callout).foregroundColor(.secondary).padding(18)
  }.background(Color(white:0.1)).preferredColorScheme(.dark).tint(gold).frame(minWidth:1050,minHeight:720)
  .alert("Foliobruma Scanner",isPresented:Binding(get:{model.error != nil},set:{if !$0 {model.error=nil}})){Button("OK"){model.error=nil}}message:{Text(model.error ?? "")}
  .sheet(isPresented:$rename){VStack(spacing:20){Text("Name your document").font(.title2);TextField("Document name",text:$model.document.title);Button("Done"){do{try model.persist();rename=false}catch{model.error=error.localizedDescription}}.keyboardShortcut(.defaultAction)}.padding(30).frame(width:380)}
  .onAppear{if model.devices.contains(where:{$0.localizedName.contains("IRIS")}){model.connect()}}
 }
 func dimensionsRatio(_ text:String)->Double {let nums=text.components(separatedBy:" × ").compactMap(Double.init);return nums.count==2 && nums[1]>0 ? nums[0]/nums[1]:16/9}
}
#if !SCANNER_TESTS
@main struct FoliobrumaApp:App {
 var body:some Scene {WindowGroup("Foliobruma Scanner"){ContentView()}.windowStyle(.hiddenTitleBar).defaultSize(width:1440,height:1000).commands{CommandGroup(replacing:.newItem){}}}
}

#endif
