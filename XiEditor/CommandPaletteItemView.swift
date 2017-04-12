//
//  CommandPaletteItemView.swift
//  XiEditor
//
//  Created by Colin Rofls on 2017-04-11.
//  Copyright © 2017 Raph Levien. All rights reserved.
//

import Cocoa

class CommandPaletteItemView: FlippedView {
    var mainLabel: NSTextField!
    
    override var wantsUpdateLayer: Bool {
        return true
    }
    
    lazy private var bottomBorder: CALayer = {
        let border = CALayer()
        border.borderColor = NSColor.lightGray.cgColor
        border.borderWidth = 0.5
        border.frame = CGRect(x: self.mainLabel.frame.minX, y: self.frame.height-0.5, width: self.mainLabel.frame.width, height: 0.5)
        border.isHidden = true
        self.layer!.addSublayer(border)
        return border
    }()

    lazy private var topBorder: CALayer = {
        let border = CALayer()
        border.borderColor = NSColor.lightGray.cgColor
        border.borderWidth = 0.5
        border.frame = CGRect(x: self.mainLabel.frame.minX, y: 0.5, width: self.mainLabel.frame.width, height: 0.5)
        border.isHidden = true
        self.layer!.addSublayer(border)
        return border
    }()

    public var showTopBorder = false
    public var showBottomBorder = false
    public var isSelected = false {
        didSet {
            mainLabel.textColor = isSelected ? NSColor.selectedMenuItemTextColor : NSColor.black
            self.needsDisplay = true
        }
    }
    
    public var item: CommandPaletteItem? {
        didSet {
            mainLabel.stringValue = item?.displayName ?? "Something!"
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
        mainLabel = NSTextField(frame: NSZeroRect)
        mainLabel.font = NSFont.systemFont(ofSize: 16)
        mainLabel.stringValue = "Placeholder"
        mainLabel.isEditable = false
        mainLabel.isBordered = false
        mainLabel.drawsBackground = false
        mainLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(mainLabel)

        self.addConstraints([
            NSLayoutConstraint(item: self, attribute: .leading, relatedBy: .equal, toItem: mainLabel, attribute: .leading, multiplier: 1.0, constant: -8.0),
            NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: mainLabel, attribute: .trailing, multiplier: 1.0, constant: 8.0),
            NSLayoutConstraint(item: self, attribute: .centerY, relatedBy: .equal, toItem: mainLabel, attribute: .centerY, multiplier: 1.0, constant: 0),
            ])
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func updateLayer() {
        topBorder.isHidden = !showTopBorder
        bottomBorder.isHidden = !showBottomBorder
        self.layer?.backgroundColor = isSelected ? NSColor.selectedMenuItemColor.cgColor : NSColor.white.cgColor
    }
}
