// Copyright 2017 Google Inc. All rights reserved.
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

struct Command: CommandPaletteItem {
    let displayName: String
    let methodName: String
    
    static func _debugCommands() -> [Command] {
        return ["Change Theme", "Rustfmt", "Python - pep8",
                "Disable Plugin", "Enable Plugin", "Open Settings",
                "Markdown Preview", "Open in Browser", "Copy as HTML",
                "Git Status", "Git Add"].map({ Command(displayName: $0, methodName: $0) })
    }
}

protocol CommandPaletteDelegate {
    func dismissCommandPalette(_ palette: CommandPaletteViewController)
    func commandPalette(_ palette: CommandPaletteViewController, didSelectItem selectedItem: CommandPaletteItem)
}

/// The CommandPaletteItem protocol describes the interface of items which can be shown in a CommandPallete.
protocol CommandPaletteItem {
    /// Human readable description of this item.
    var displayName: String { get }
}

/// A CommandPaletteViewController displays a CommandPaletteView, which is used to fuzzily search through a set of options.
class CommandPaletteViewController: NSViewController, NSTextFieldDelegate {

    enum ArrowKey: UInt16 {
        case Left = 123
        case Right = 124
        case Down = 125
        case Up = 126
    }

    //TODO: Move to an API where self.show takes some items and a completion callback
    var delegate: CommandPaletteDelegate!
    var _items = Command._debugCommands()
    public var maxItems: Int = 5
    
    private let textFieldHeight: CGFloat = 60
    private let itemViewHeight: CGFloat = 40
    private var selectedIdx: Int = 0 {
        didSet {
            guard selectedIdx != oldValue else { return }
            if oldValue < self.activeItemViews.count {
                self.activeItemViews[oldValue].isSelected = false
            }
            if selectedIdx < self.activeItemViews.count {
                self.activeItemViews[selectedIdx].isSelected = true
            }
        }
    }

    @IBOutlet weak var commandTextField: NSTextField!

    private var activeItemViews: [CommandPaletteItemView] = []
    private var reusableItemViews: [CommandPaletteItemView] = []

    private var arrowKeyEventHandler: Any?

    override func viewDidLoad() {
        super.viewDidLoad()
        commandTextField.delegate = self
        self.arrowKeyEventHandler = NSEvent.addLocalMonitorForEvents(matching: NSKeyDownMask) { (event) -> NSEvent? in
            // the monitor stays active even if we aren't visible; in that case we no-op
            guard self.view.superview != nil else { return event }
            if let arrowKey = ArrowKey(rawValue: event.keyCode) {
                switch arrowKey {
                case .Up, .Down:
                    self.handleArrowKey(arrowKey)
                    return nil
                default:
                    return event
                }
            } else {
                return event
            }
        }
    }
    
    deinit {
        NSEvent.removeMonitor(arrowKeyEventHandler!)
    }
    
    /// Displays the command palette within a view.
    public func present(inView parentView: NSView) {
        parentView.addSubview(self.view)
        self.view.frame = NSRect(x: NSMidX(parentView.frame) - (self.view.frame.width / 2), y: 10, width: self.view.frame.width, height: self.view.frame.height)
        self.updateResults(forQuery: commandTextField.stringValue)
        parentView.window?.makeFirstResponder(commandTextField)
    }
    
    /// Closes the command palette, removing it from its superview.
    public func dismiss() {
        self.view.removeFromSuperview()
    }
    
    private func updateItems(items: [CommandPaletteItem]) {
        let nbItems = min(items.count, self.maxItems)
        while nbItems < activeItemViews.count {
            let surplusView = activeItemViews.popLast()!
            surplusView.removeFromSuperview()
            reusableItemViews.append(surplusView)
        }
        
        while nbItems > activeItemViews.count {
            activeItemViews.append(self.reusableItemView())
        }
        
        self.view.frame = NSRect(
            origin: self.view.frame.origin,
            size: CGSize(width: self.view.frame.width, height: textFieldHeight + itemViewHeight * CGFloat(nbItems) + (self.view as! CommandPaletteView).cornerRadius))
        // manually reposition the command text field, or it gets clobbered when the parent view is resized
        commandTextField.frame = NSRect(x: 8, y: 13, width: commandTextField.frame.width, height: commandTextField.frame.height)
        
        for (idx, item) in items[0..<nbItems].enumerated() {
            let itemView = activeItemViews[idx]
            itemView.item = item
            itemView.frame = NSRect(x: 0, y: textFieldHeight + itemViewHeight * CGFloat(idx), width: self.view.frame.width, height: itemViewHeight)
            itemView.showTopBorder = (idx == 0)
            itemView.isSelected = (idx == selectedIdx)
            itemView.showBottomBorder = (idx + 1 != nbItems)
            itemView.needsDisplay = true
        }
    }

    private func reusableItemView() -> CommandPaletteItemView {
        let newItemView: CommandPaletteItemView
        if reusableItemViews.count > 0 {
            newItemView = reusableItemViews.popLast()!
        } else {
            newItemView = CommandPaletteItemView(frame: NSZeroRect)
        }
        self.view.addSubview(newItemView)
        return newItemView
    }

    private func handleArrowKey(_ key: ArrowKey) {
        switch key {
        case .Up:
            self.selectedIdx = max(0, self.selectedIdx - 1)
        case .Down:
            self.selectedIdx = min(activeItemViews.count - 1, self.selectedIdx + 1)
        default:
            break
        }
    }
    
    private func updateResults(forQuery text: String) {
        self.selectedIdx = 0
        let rankings = _items.map({ (item: $0, score: $0.displayName.score(text, fuzziness: 0.5)) })
            .filter({ $0.score > 0.25 })
            .sorted(by: { $0.score > $1.score })

        updateItems(items: rankings.map({ $0.item }))
    }

    
    override func controlTextDidChange(_ obj: Notification) {
        let newText = commandTextField.stringValue
        updateResults(forQuery: newText)
    }

    @IBAction func textFieldAction(_ sender: Any) {
        if self.activeItemViews.count > 0 {
            self.delegate.commandPalette(self, didSelectItem: self.activeItemViews[selectedIdx].item!)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        self.selectedIdx = 0
        for view in activeItemViews {
            view.removeFromSuperview()
            reusableItemViews.append(view)
        }
        activeItemViews.removeAll()
        delegate.dismissCommandPalette(self)
    }
}

