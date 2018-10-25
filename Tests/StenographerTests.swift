// StenographerTests.swift
//
// Copyright (c) 2018 Stenographer
//
// Copyright (c) 2015 - 2016 Justin Pawela & The LogKit Project
// http://www.logkit.info/
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

import Foundation
import XCTest
@testable import Stenographer

class PriorityLevelTests: XCTestCase {

    func testPriorities() {
        XCTAssertEqual(SXPriorityLevel.error, SXPriorityLevel.error, "SXPriorityLevel: .Error != .Error")
        XCTAssertNotEqual(SXPriorityLevel.info, SXPriorityLevel.notice, "SXPriorityLevel: .Info == .Notice")
        XCTAssertEqual(
            min(SXPriorityLevel.all, SXPriorityLevel.debug, SXPriorityLevel.info, SXPriorityLevel.notice,
                SXPriorityLevel.warning, SXPriorityLevel.error, SXPriorityLevel.critical, SXPriorityLevel.none),
            SXPriorityLevel.all, "SXPriorityLevel: .All is not minimum")
        XCTAssertLessThan(SXPriorityLevel.debug, SXPriorityLevel.info, "SXPriorityLevel: .Debug !< .Info")
        XCTAssertLessThan(SXPriorityLevel.info, SXPriorityLevel.notice, "SXPriorityLevel: .Info !< .Notice")
        XCTAssertLessThan(SXPriorityLevel.notice, SXPriorityLevel.warning, "SXPriorityLevel: .Notice !< .Warning")
        XCTAssertLessThan(SXPriorityLevel.warning, SXPriorityLevel.error, "SXPriorityLevel: .Warning !< .Error")
        XCTAssertLessThan(SXPriorityLevel.info, SXPriorityLevel.critical, "SXPriorityLevel: .Error !< .Critical")
        XCTAssertEqual(
            max(SXPriorityLevel.all, SXPriorityLevel.debug, SXPriorityLevel.info, SXPriorityLevel.notice,
                SXPriorityLevel.warning, SXPriorityLevel.error, SXPriorityLevel.critical, SXPriorityLevel.none),
            SXPriorityLevel.none, "SXPriorityLevel: .None is not maximum")
    }

}


class ConsoleEndpointTests: XCTestCase {

    let endpoint = SXConsoleEndpoint()

    func testWrite() {
        self.endpoint.write("Hello from the Console Endpoint!")
    }

}

class FileEndpointTests: XCTestCase {

    var endpoint: SXFileEndpoint?
    let endpointURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("info.logkit.test", isDirectory: true)
        .appendingPathComponent("info.logkit.test.endpoint.file", isDirectory: false)

    override func setUp() {
        super.setUp()
        self.endpoint = SXFileEndpoint(fileURL: self.endpointURL, shouldAppend: false)
        XCTAssertNotNil(self.endpoint, "Could not create Endpoint")
    }

    override func tearDown() {
        self.endpoint?.resetCurrentFile()
//        self.endpoint = nil //TODO: do we need an endpoint close method?
//        try! NSFileManager.defaultManager().removeItemAtURL(self.endpointURL)
        //FIXME: crashes because Endpoint has not deinitialized yet
        super.tearDown()
    }

    func testFileURLOutput() {
        print("\(type(of: self)) temporary file URL: \(self.endpointURL.absoluteString)")
    }

    func testRotation() {
        let startURL = self.endpoint?.currentURL
        XCTAssertEqual(self.endpointURL, startURL, "Endpoint opened with unexpected URL")
        self.endpoint?.rotate()
        XCTAssertEqual(self.endpoint?.currentURL, startURL, "File Endpoint should not rotate files")
    }

    #if !os(watchOS) // watchOS 2 does not support extended attributes
    func testXAttr() {
        let key = "info.logkit.endpoint.FileEndpoint"
        let path = self.endpoint?.currentURL.path
        XCTAssertGreaterThanOrEqual(getxattr(path!, key, nil, 0, 0, 0), 0, "The xattr is not present")
        XCTAssertEqual(removexattr(path!, key, 0), 0, "The xattr could not be removed")
    }
    #endif

    func testWrite() {
        let testString = "Hello 👮🏾 from the File Endpoint!"
        let writeCount = Array(1...4)
        writeCount.forEach({ _ in self.endpoint?.write(testString) })
        let bytes = writeCount.flatMap({ _ in testString.utf8 })
        let canonical = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
        let _ = self.endpoint?.barrier() // Doesn't return until the writes are finished.
        XCTAssert(try! Data(contentsOf: self.endpoint!.currentURL) == canonical)
    }

}

class RotatingFileEndpointTests: XCTestCase {

    var endpoint: SXRotatingFileEndpoint?
    let endpointURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("info.logkit.test", isDirectory: true)
        .appendingPathComponent("info.logkit.test.endpoint.rotatingFile", isDirectory: false)

    override func setUp() {
        super.setUp()
        self.endpoint = SXRotatingFileEndpoint(baseURL: self.endpointURL, numberOfFiles: 5)
        XCTAssertNotNil(self.endpoint, "Could not create Endpoint")
    }

    override func tearDown() {
        self.endpoint?.resetCurrentFile()
        super.tearDown()
    }

    func testRotation() {
        let startURL = self.endpoint?.currentURL
        self.endpoint?.rotate()
        XCTAssertNotEqual(self.endpoint?.currentURL, startURL, "URLs should not match after just one rotation")
        self.endpoint?.rotate()
        self.endpoint?.rotate()
        self.endpoint?.rotate()
        self.endpoint?.rotate()
        XCTAssertEqual(self.endpoint?.currentURL, startURL, "URLs don't match after full rotation cycle")
    }

    #if !os(watchOS) // watchOS 2 does not support extended attributes
    func testXAttr() {
        let key = "info.logkit.endpoint.RotatingFileEndpoint"
        var path = self.endpoint?.currentURL.path
        XCTAssertGreaterThanOrEqual(getxattr(path!, key, nil, 0, 0, 0), 0, "The xattr is not present")
        XCTAssertEqual(removexattr(path!, key, 0), 0, "The xattr could not be removed")
        self.endpoint?.rotate()
        path = self.endpoint?.currentURL.path
        XCTAssertGreaterThanOrEqual(getxattr(path!, key, nil, 0, 0, 0), 0, "The xattr is not present")
        XCTAssertEqual(removexattr(path!, key, 0), 0, "The xattr could not be removed")
    }
    #endif

    func testWrite() {
        self.endpoint?.resetCurrentFile()
        let testString = "Hello 🎅🏽 from the Rotating File Endpoint!"
        let writeCount = Array(1...4)
        writeCount.forEach({ _ in self.endpoint?.write(testString) })
        let bytes = writeCount.flatMap({ _ in testString.utf8 })
        let canonical = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
        let _ = self.endpoint?.barrier() // Doesn't return until the writes are finished.
        XCTAssert(try! Data(contentsOf: self.endpoint!.currentURL) == canonical)
    }

}

class DatedFileEndpointTests: XCTestCase {

    var endpoint: SXDatedFileEndpoint?
    let endpointURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("info.logkit.test", isDirectory: true)
        .appendingPathComponent("info.logkit.test.endpoint.datedFile", isDirectory: false)

    override func setUp() {
        super.setUp()
        self.endpoint = SXDatedFileEndpoint(baseURL: self.endpointURL)
        XCTAssertNotNil(self.endpoint, "Could not create Endpoint")
    }

    override func tearDown() {
        self.endpoint?.resetCurrentFile()
        super.tearDown()
    }

    func testRotation() {
        let startURL = self.endpoint?.currentURL
        self.endpoint?.rotate()
        XCTAssertEqual(self.endpoint?.currentURL, startURL, "Dated File Endpoint should not manually rotate files")
    }

    #if !os(watchOS) // watchOS 2 does not support extended attributes
    func testXAttr() {
        let key = "info.logkit.endpoint.DatedFileEndpoint"
        let path = self.endpoint?.currentURL.path
        XCTAssertGreaterThanOrEqual(getxattr(path!, key, nil, 0, 0, 0), 0, "The xattr is not present")
        XCTAssertEqual(removexattr(path!, key, 0), 0, "The xattr could not be removed")
    }
    #endif

    func testWrite() {
        self.endpoint?.resetCurrentFile()
        let testString = "Hello 👷🏼 from the Dated File Endpoint!"
        let writeCount = Array(1...4)
        writeCount.forEach({ _ in self.endpoint?.write(testString) })
        let bytes = writeCount.flatMap({ _ in testString.utf8 })
        let canonical = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
        let _ = self.endpoint?.barrier() // Doesn't return until the writes are finished.
        XCTAssert(try! Data(contentsOf: self.endpoint!.currentURL) == canonical)
    }
    
}

class HTTPEndpointTests: XCTestCase {

    let endpoint = SXHTTPEndpoint(URL: URL(string: "https://httpbin.org/post/")!, HTTPMethod: "POST")

    func testWrite() {
        self.endpoint.write("Hello from the HTTP Endpoint!")
    }

}

class LoggerTests: XCTestCase {

    var log: SXLogger?
    var fileEndpoint: SXFileEndpoint?
    let endpointURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("info.logkit.test", isDirectory: true)
        .appendingPathComponent("info.logkit.test.logger", isDirectory: false)
    let entryFormatter = SXEntryFormatter({ e in "[\(e.level.uppercased())] \(e.message)" }) // Nothing variable.

    override func setUp() {
        super.setUp()
        self.fileEndpoint = SXFileEndpoint(fileURL: self.endpointURL, shouldAppend: false, entryFormatter: self.entryFormatter)
        XCTAssertNotNil(self.fileEndpoint, "Failed to init File Endpoint")
        self.log = SXLogger(endpoints: [ self.fileEndpoint, ])
        XCTAssertNotNil(self.log, "Failed to init Logger")
    }

    override func tearDown() {
        self.fileEndpoint?.resetCurrentFile()
        super.tearDown()
    }

    func testLog() {
        self.log?.debug("debug")
        self.log?.info("info")
        self.log?.notice("notice")
        self.log?.warning("warning")
        self.log?.error("error")
        self.log?.critical("critical")

        let targetContent = [
            "[DEBUG] debug", "[INFO] info", "[NOTICE] notice", "[WARNING] warning", "[ERROR] error", "[CRITICAL] critical",
        ].joined(separator: "\n") + "\n"
        
        self.fileEndpoint?.barrier() // Doesn't return until the writes are finished.

        let actualContent = try! String(contentsOf: self.fileEndpoint!.currentURL, encoding: String.Encoding.utf8)

        XCTAssertEqual(actualContent, targetContent, "Output does not match expected output")
    }
}
