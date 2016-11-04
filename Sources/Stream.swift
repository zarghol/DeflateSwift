/*
* Stream.swift
*
* Copyright (C) 2016 Clément Nonn. All Rights Reserved.
* Created by Josh Baker (joshbaker77@gmail.com), Modified by Clément Nonn
*
* This software may be modified and distributed under the terms
* of the MIT license.  See the LICENSE file for details.
*
*/

import Foundation

enum ZStreamError: Error {
    case streamEnd
    case needDict
    case errNo(Int)
    case streamError
    case dataError
    case memError
    case bufError
    case versionError
    case undefinedError
    
    init(errorCode: Int) {
        switch errorCode {
        case 1:
            self = .streamEnd
        case 2:
            self = .needDict
        case -1:
            self = .errNo(-1)
        case -2:
            self = .streamError
        case -3:
            self = .dataError
        case -4:
            self = .memError
        case -5:
            self = .bufError
        case -6:
            self = .versionError
        default:
            self = .undefinedError
        }
    }
}

private struct StreamStruct {
    fileprivate var next_in : UnsafePointer<UInt8>? = nil
    fileprivate var avail_in : CUnsignedInt = 0
    fileprivate var total_in : CUnsignedLong = 0
    
    fileprivate var next_out : UnsafePointer<UInt8>? = nil
    fileprivate var avail_out : CUnsignedInt = 0
    fileprivate var total_out : CUnsignedLong = 0
    
    fileprivate var msg : UnsafePointer<CChar>? = nil
    fileprivate var state : OpaquePointer? = nil
    
    fileprivate var zalloc : OpaquePointer? = nil
    fileprivate var zfree : OpaquePointer? = nil
    fileprivate var opaque : OpaquePointer? = nil
    
    fileprivate var data_type : CInt = 0
    fileprivate var adler : CUnsignedLong = 0
    fileprivate var reserved : CUnsignedLong = 0
}

public class ZStream {
    
    @_silgen_name("zlibVersion") internal static func zlibVersion() -> OpaquePointer
    
    internal static var c_version: OpaquePointer = ZStream.zlibVersion()
    public static let version: String = String(format: "%s", locale: nil, c_version)
    
    fileprivate var strm = StreamStruct()
    
    internal var deflater = true
    internal var initd = false
    
    internal var hasCustomWindowBits: Bool {
        //  a true uniquement si windowsBits custom
        return windowBits != 15
    }
    
    internal var level = CInt(-1)
    internal var windowBits = CInt(15)
    
    fileprivate var out = [UInt8](repeating: 0, count: 5000)
    
    private(set) fileprivate var isInitialized = false
    func initalize() throws {
        isInitialized = true
    }

}
protocol StreamZip {
    func write(bytes: [UInt8], flush: Bool) throws -> [UInt8]
}

// Compress
public class Compressor : ZStream, StreamZip {
    @_silgen_name("deflateInit2_") private func deflateInit(strm: UnsafeMutableRawPointer, level: CInt, method: CInt, windowBits: CInt, memLevel: CInt, strategy: CInt, version: OpaquePointer, stream_size: CInt) -> CInt
    @_silgen_name("deflateInit_") private func deflateInit(strm: UnsafeMutableRawPointer, level: CInt, version: OpaquePointer, stream_size: CInt) -> CInt
    @_silgen_name("deflateEnd") private func deflateEnd(strm: UnsafeMutableRawPointer) -> CInt
    @_silgen_name("deflate") private func deflate(strm: UnsafeMutableRawPointer, flush: CInt) -> CInt
    
    public init(level: Int) {
        super.init()
        self.level = CInt(level)
    }
    
    public init(windowBits: Int) {
        super.init()
        self.windowBits = CInt(windowBits)
    }
    
    public init(level: Int, windowBits: Int) {
        super.init()
        self.level = CInt(level)
        self.windowBits = CInt(windowBits)
    }
    
    override func initalize() throws {
        if !isInitialized {
            let res: CInt
            let sizeOfStreamStruct = CInt(MemoryLayout<StreamStruct>.size)
            
            if hasCustomWindowBits {
                res = deflateInit(strm: &strm, level: level, method: 8, windowBits: windowBits, memLevel: 8, strategy: 0, version: ZStream.c_version, stream_size: sizeOfStreamStruct)
            } else {
                res = deflateInit(strm: &strm, level: level, version: ZStream.c_version, stream_size: sizeOfStreamStruct)
            }
            
            if res != 0 {
                throw ZStreamError(errorCode: Int(res))
            }
            try super.initalize()
        }
    }
    
    deinit {
        if isInitialized{
            _ = deflateEnd(strm: &strm)
        }
    }
    
    // return the bytes compressed
    public func write(bytes: [UInt8], flush: Bool) throws -> [UInt8] {
        try initalize()
        
        var bytes = bytes
        
        strm.avail_in = CUnsignedInt(bytes.count)
        strm.next_in = &bytes+0
        
        var resCode: CInt
        var result = [UInt8]()

        repeat {
            strm.avail_out = CUnsignedInt(out.count)
            strm.next_out = &out+0
            
            resCode = deflate(strm: &strm, flush: flush ? 1 : 0)
            
            if resCode < 0 {
                throw ZStreamError(errorCode: Int(resCode))
            }
            let have = out.count - Int(strm.avail_out)
            if have > 0 {
                result += Array(out[0..<have])
            }
        } while (strm.avail_out == 0 && resCode != 1)
        
        if strm.avail_in != 0 {
            throw ZStreamError.undefinedError
        }
        return result
    }
}

public class Decompressor: ZStream, StreamZip {
    @_silgen_name("inflateInit2_") private func inflateInit(strm: UnsafeMutableRawPointer, windowBits: CInt, version: OpaquePointer, stream_size: CInt) -> CInt
    @_silgen_name("inflateInit_") private func inflateInit(strm: UnsafeMutableRawPointer, version: OpaquePointer, stream_size: CInt) -> CInt
    @_silgen_name("inflate") private func inflate(strm: UnsafeMutableRawPointer, flush: CInt) -> CInt
    @_silgen_name("inflateEnd") private func inflateEnd(strm: UnsafeMutableRawPointer) -> CInt
    
    override func initalize() throws {
        if !isInitialized {
            let res: CInt
            let sizeOfStreamStruct = CInt(MemoryLayout<StreamStruct>.size)
            
            if hasCustomWindowBits {
                res = inflateInit(strm: &strm, windowBits: windowBits, version: ZStream.c_version, stream_size: sizeOfStreamStruct)
            } else {
                res = inflateInit(strm: &strm, version: ZStream.c_version, stream_size: sizeOfStreamStruct)
            }
            
            if res != 0 {
                throw ZStreamError(errorCode: Int(res))
            }
            try super.initalize()
        }
    }

    public init(windowBits: Int) {
        super.init()
        self.windowBits = CInt(windowBits)
    }
    
    
    deinit {
        if isInitialized{
            _ = inflateEnd(strm: &strm)
        }
    }

    // return decompressed data
    public func write(bytes : [UInt8], flush: Bool) throws -> [UInt8] {
        var bytes = bytes
        
        var res: CInt
        var result = [UInt8]()
        
        strm.avail_in = CUnsignedInt(bytes.count)
        strm.next_in = &bytes+0
        
        repeat {
            strm.avail_out = CUnsignedInt(out.count)
            strm.next_out = &out+0
            
            res = inflate(strm: &strm, flush: flush ? 1 : 0)
            
            if res < 0 {
                throw ZStreamError(errorCode: Int(res))
            }
            let have = out.count - Int(strm.avail_out)
            if have > 0 {
                result += Array(out[0..<have])
            }
        } while (strm.avail_out == 0 && res != 1)
        
        if strm.avail_in != 0 {
            throw ZStreamError.undefinedError
        }
        return result
    }


}
