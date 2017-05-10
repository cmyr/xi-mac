// Copyright 2016 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Cocoa

struct PendingNotification {
    let method: String
    let params: Any
}

class Document: NSDocument {
    
    /// used internally to force open to an existing empty document when present.
    static var _documentForNextOpenCall: Document?

    /// used internally to keep track of groups of tabs
    static fileprivate var _nextTabbingIdentifier = 0

    /// returns the next available tab group identifer. When we create a new window, if it is not part of an existing tab group it is assigned a new one.
    static private func nextTabbingIdentifier() -> String {
        _nextTabbingIdentifier += 1
        return "tab-group-\(_nextTabbingIdentifier)"
    }

    /// if set, should be used as the tabbingIdentifier of new documents' windows.
    static var preferredTabbingIdentifier: String?

    var dispatcher: Dispatcher!
    /// coreViewIdentifier is the name used to identify this document when communicating with the Core.
    var coreViewIdentifier: ViewIdentifier? {
        didSet {
            guard let identifier = coreViewIdentifier else { return }
            // on first set, request initial plugins
            if oldValue == nil {
                let req = Events.InitialPlugins(viewIdentifier: identifier)
                dispatcher.coreConnection.sendRpcAsync(
                req.method, params: req.params!) { [unowned self] (response) in
                    DispatchQueue.main.async {
                        self.editViewController!.availablePlugins = response as! [String]
                    }
                }
            }
            // apply initial updates when coreViewIdentifier is set
            for pending in self.pendingNotifications {
                self.sendRpcAsync(pending.method, params: pending.params)
            }
            self.pendingNotifications.removeAll()
        }
    }
    
    /// Identifier used to group windows together into tabs.
    /// - Todo: I suspect there is some potential confusion here around dragging tabs into and out of windows? 
    /// I.e I'm not sure if the system ever modifies the tabbingIdentifier on our windows,
    /// which means these could get out of sync. But: nothing obviously bad happens when I test it.
    /// If this is problem we could use KVO to keep these in sync.
    var tabbingIdentifier: String
    
	var pendingNotifications: [PendingNotification] = [];
    var editViewController: EditViewController?

    /// used to keep track of whether we're in the process of reusing an empty window
    fileprivate var _skipShowingWindow = false

    // called only when creating a _new_ document
    convenience init(type: String) throws {
        self.init()
        self.fileType = type
        Events.NewView(path: nil).dispatchWithCallback(dispatcher!) { (response) in
            DispatchQueue.main.async {
                self.coreViewIdentifier = response
            }
        }
    }
    
    // called when opening a document
    convenience init(contentsOf url: URL, ofType typeName: String) throws {
        self.init()
        self.fileURL = url
        self.fileType = typeName
        Events.NewView(path: url.path).dispatchWithCallback(dispatcher!) { (response) in
            DispatchQueue.main.async {
                self.coreViewIdentifier = response
            }
        }
        try self.read(from: url, ofType: typeName)
    }
    
    // called when NSDocument reopens documents on launch
    convenience init(for urlOrNil: URL?, withContentsOf contentsURL: URL, ofType typeName: String) throws {
        try self.init(contentsOf: contentsURL, ofType: typeName)
    }
    
    override init() {
        dispatcher = (NSApplication.shared().delegate as? AppDelegate)?.dispatcher
        tabbingIdentifier = Document.preferredTabbingIdentifier ?? Document.nextTabbingIdentifier()
        super.init()
        // I'm not 100% sure this is necessary but it can't _hurt_
        self.hasUndoManager = false
    }
 
    override func makeWindowControllers() {
        var windowController: NSWindowController!
        // check to see if we should reuse another document's window
        if let existing = Document._documentForNextOpenCall {
            assert(existing.windowControllers.count == 1, "each document should only and always own a single windowController")
            windowController = existing.windowControllers[0]
            Document._documentForNextOpenCall = nil
            // if we're reusing an existing window, we want to noop on the `showWindows()` call we receive from the DocumentController
            _skipShowingWindow = true
            tabbingIdentifier = existing.tabbingIdentifier
        } else {
            // if we aren't reusing, create a new window as normal:
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as! NSWindowController
            
            if #available(OSX 10.12, *) {
                windowController.window?.tabbingIdentifier = tabbingIdentifier
                // preferredTabbingIdentifier is set when a new document is created with cmd-T. When this is the case, set the window's tabbingMode.
                if Document.preferredTabbingIdentifier != nil {
                    windowController.window?.tabbingMode = .preferred
                }
            }
            //FIXME: some saner way of positioning new windows. maybe based on current window size, with some checks to not completely obscure an existing window?
            // also awareness of multiple screens (prefer to open on currently active screen)
            let screenHeight = windowController.window?.screen?.frame.height ?? 800
            let windowHeight: CGFloat = 800
            windowController.window?.setFrame(NSRect(x: 200, y: screenHeight - windowHeight - 200, width: 700, height: 800), display: true)
        }

        self.editViewController = windowController.contentViewController as? EditViewController
        editViewController?.document = self
        windowController.window?.delegate = editViewController
        self.addWindowController(windowController)
    }

    override func showWindows() {
        // part of our code to reuse existing windows when opening documents
        assert(windowControllers.count == 1, "documents should have a single window controller")
        if !(_skipShowingWindow) {
            super.showWindows()
        } else {
            _skipShowingWindow = false
        }
    }
    
    override func save(to url: URL, ofType typeName: String, for saveOperation: NSSaveOperationType, completionHandler: @escaping (Error?) -> Void) {
        self.fileURL = url
        self.save(url.path)
        //TODO: save operations should report success, and we should pass any errors to the completion handler
        completionHandler(nil)
    }

    // Document.close() can be called multiple times (on window close and application terminate)
    override func close() {
        if let identifier = self.coreViewIdentifier {
            self.coreViewIdentifier = nil
            Events.CloseView(viewIdentifier: identifier).dispatch(dispatcher!)
            super.close()
        }
    }
    
    override var isEntireFileLoaded: Bool {
        return false
    }
    
    override class func autosavesInPlace() -> Bool {
        return false
    }

    override func read(from data: Data, ofType typeName: String) throws {
        // required override. xi-core handles file reading.
    }
    
    fileprivate func save(_ filename: String) {
        Events.Save(viewIdentifier: coreViewIdentifier!, path: filename).dispatch(dispatcher!)
    }
    
    /// Send a notification specific to the tab. If the tab name hasn't been set, then the
    /// notification is queued, and sent when the tab name arrives.
    func sendRpcAsync(_ method: String, params: Any) {
        if let coreViewIdentifier = coreViewIdentifier {
            let inner = ["method": method, "params": params, "view_id": coreViewIdentifier] as [String : Any]
            dispatcher?.coreConnection.sendRpcAsync("edit", params: inner)
        } else {
            pendingNotifications.append(PendingNotification(method: method, params: params))
        }
    }

    /// Note: this is a blocking call, and will also fail if the tab name hasn't been set yet.
    /// We should try to migrate users to either fully async or callback based approaches.
    func sendRpc(_ method: String, params: Any) -> Any? {
        let inner = ["method": method as AnyObject, "params": params, "view_id": coreViewIdentifier as AnyObject] as [String : Any]
        return dispatcher?.coreConnection.sendRpc("edit", params: inner)
    }

    func update(_ content: [String: AnyObject]) {
        if let editVC = editViewController {
            editVC.update(content)
        }
    }
}
