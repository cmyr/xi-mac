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
