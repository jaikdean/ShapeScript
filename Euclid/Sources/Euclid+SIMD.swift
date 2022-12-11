//
//  Euclid+SIMD.swift
//  Euclid
//
//  Created by Nick Lockwood on 05/10/2022.
//  Copyright © 2022 Nick Lockwood. All rights reserved.
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/Euclid
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#if canImport(simd)

import simd

public extension simd_double3 {
    /// Creates a simd vector 3 from a Euclid `Vector`.
    /// - Parameter vector: A Euclid vector.
    init(_ vector: Vector) {
        self.init(vector.x, vector.y, vector.z)
    }
}

public extension simd_float3 {
    /// Creates a simd float vector 3 from a Euclid `Vector`.
    /// - Parameter vector: A Euclid vector.
    init(_ vector: Vector) {
        self.init(Float(vector.x), Float(vector.y), Float(vector.z))
    }
}

public extension simd_float2 {
    /// Creates a simd float vector 2 from a Euclid `Vector`.
    /// - Parameter vector: A Euclid vector.
    init(_ vector: Vector) {
        self.init(Float(vector.x), Float(vector.y))
    }
}

public extension Vector {
    /// Creates a `Vector` from a simd vector 3.
    /// - Parameter vector: A simd vector.
    init(_ vector: simd_double3) {
        self.init(vector.x, vector.y, vector.z)
    }
}

public extension simd_quatd {
    /// Creates a simd quaternion from a Euclid `Rotation`.
    /// - Parameter rotation: A Euclid rotation.
    init(_ rotation: Rotation) {
        self.init(rotation.quaternion)
    }

    /// Creates a simd quaternion from a Euclid `Quaternion`.
    /// - Parameter quaternion: A Euclid quaternion.
    init(_ quaternion: Quaternion) {
        self = quaternion.storage
    }
}

public extension simd_quatf {
    /// Creates a simd float quaternion from a Euclid `Rotation`.
    /// - Parameter rotation: A Euclid rotation.
    init(_ rotation: Rotation) {
        self.init(rotation.quaternion)
    }

    /// Creates a simd float quaternion from a Euclid `Quaternion`.
    /// - Parameter q: A Euclid quaternion.
    init(_ q: Quaternion) {
        self.init(ix: Float(q.x), iy: Float(q.y), iz: Float(q.z), r: Float(q.w))
    }
}

public extension Rotation {
    /// Creates a `Rotation` from a simd quaternion.
    /// - Parameter quaternion: A simd quaternion.
    init(_ quaternion: simd_quatd) {
        self.init(Quaternion(quaternion))
    }
}

public extension Quaternion {
    /// Creates a `Quaternion` from a simd quaternion.
    /// - Parameter quaternion: A simd quaternion.
    init(_ quaternion: simd_quatd) {
        self.storage = quaternion
    }
}

#endif
