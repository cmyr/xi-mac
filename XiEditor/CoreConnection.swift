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

import Foundation

class CoreConnection {

    var inHandle: FileHandle  // stdin of core process
    var recvBuf: Data
    var callback: (Any) -> Any?

    // RPC state
    var queue = DispatchQueue(label: "com.levien.xi.CoreConnection", attributes: [])
    var rpcIndex = 0
    var pending = Dictionary<Int, (Any?) -> ()>()

    init(path: String, callback: @escaping (Any) -> Any?) {
        let task = Process()
        task.launchPath = path
        task.arguments = []
        let outPipe = Pipe()
        task.standardOutput = outPipe
        let inPipe = Pipe()
        task.standardInput = inPipe
        inHandle = inPipe.fileHandleForWriting
        recvBuf = Data()
        self.callback = callback
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            self.recvHandler(data)
        }
        task.launch()
    }

    func recvHandler(_ data: Data) {
        if data.count == 0 {
            print("eof")
            return
        }
        let scanStart = recvBuf.count
        recvBuf.append(data)
        let recvBufLen = recvBuf.count
        recvBuf.withUnsafeMutableBytes { (recvBufBytes: UnsafeMutablePointer<UInt8>) -> Void in
            var i = 0
            for j in scanStart..<recvBufLen {
                // TODO: using memchr would probably be faster
                if recvBufBytes[j] == UInt8(ascii:"\n") {
                    let dataPacket = recvBuf.subdata(in: i ..< j + 1)
                    handleRaw(dataPacket)
                    i = j + 1
                }
            }
            if i < recvBufLen {
                memmove(recvBufBytes, recvBufBytes + i, recvBufLen - i)
            }
            recvBuf.count = recvBufLen - i
        }
    }

    func sendJson(_ json: Any) {
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            let mutdata = NSMutableData()
            mutdata.append(data)
            let nl = [0x0a as UInt8]
            mutdata.append(nl, length: 1)
            inHandle.write(mutdata as Data)
        } catch _ {
            print("error serializing to json")
        }
    }

    func handleRaw(_ data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
//            print("got \(json)")
            handleRpc(json as Any)
        } catch {
            print("json error \(error.localizedDescription)")
        }
    }

    /// handle a JSON RPC call. Determines whether it is a request, response or notifcation
    /// and executes/responds accordingly
    func handleRpc(_ json: Any) {
        if let obj = json as? [String: Any], let index = obj["id"] as? Int {
            if let result = obj["result"] { // is response
                var callback: ((Any?) -> ())?
                queue.sync {
                    callback = self.pending.removeValue(forKey: index)
                }
                callback?(result)
            } else { // is request
                DispatchQueue.main.async {
                    let result = self.callback(json as AnyObject)
                    let resp = ["id": index, "result": result] as [String : Any?]
                    self.sendJson(resp as Any)
                }
            }
        } else { // is notification
            DispatchQueue.main.async {
                let _ = self.callback(json as AnyObject)
            }
        }
    }

    /// send an RPC request, returning immediately. The callback will be called when the
    /// response comes in, likely from a different thread
    func sendRpcAsync(_ method: String, params: Any, callback: ((Any?) -> ())? = nil) {
        var req = ["method": method, "params": params] as [String : Any]
        if let callback = callback {
            queue.sync {
                let index = self.rpcIndex
                req["id"] = index
                self.rpcIndex += 1
                self.pending[index] = callback
            }
        }
        sendJson(req as Any)
    }

    /// send RPC synchronously, blocking until return. Note: there is no ordering guarantee on
    /// when this function may return. In particular, an async notification sent by the core after
    /// a response to a synchronous RPC may be delivered before it.
    func sendRpc(_ method: String, params: Any) -> Any? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Any? = nil
        sendRpcAsync(method, params: params) { r in
            result = r
            semaphore.signal()
        }
        let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        return result
    }
}
