/*
 * Zipper.swift
 *
 * Copyright (C) 2016 Clément Nonn. All Rights Reserved.
 * Created by Clément Nonn
 *
 * This software may be modified and distributed under the terms
 * of the MIT license.  See the LICENSE file for details.
 *
 */

import Foundation

extension StreamZip {
    func write(data: Data, flush: Bool) throws -> Data {
        let uint8 = data.withUnsafeBytes { [UInt8](UnsafeBufferPointer(start: $0, count: data.count)) }
        let result = try self.write(bytes: uint8, flush: flush)
        
        return Data(bytes: result)
    }
}
