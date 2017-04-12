//
//  CommandPaletteView.swift
//  XiEditor
//
//  Created by Colin Rofls on 2017-04-12.
//  Copyright © 2017 Raph Levien. All rights reserved.
//

import Cocoa

class CommandPaletteView: FlippedView {

    override var wantsUpdateLayer: Bool {
        return true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupShadow()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupShadow()
    }
    
    private func setupShadow() {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(deviceWhite: 0.8, alpha: 1.0)
        shadow.shadowBlurRadius = 4.0
        self.wantsLayer = true
        self.shadow = shadow
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = NSColor.white.cgColor
        self.layer?.cornerRadius = 5.0
    }
}
