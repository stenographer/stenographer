// ConsoleEndpoints.swift
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


//MARK: Console Writer Protocol

/**
 *  An internal protocol that facilitates `SXConsoleEndpoint` in operating
 *  either synchronously or asynchronously.
 */
private protocol SXConsoleWriter {
    func writeData(_ data: Data) -> Void
}


//MARK: Console Endpoint

/// An Endpoint that prints Log Entries to the console (`stderr`) in either a synchronous or asynchronous fashion.
open class SXConsoleEndpoint: SXEndpoint {
    /// The minimum Priority Level a Log Entry must meet to be accepted by this Endpoint.
    open var minimumPriorityLevel: SXPriorityLevel
    /// The formatter used by this Endpoint to serialize a Log Entry’s `dateTime` property to a string.
    open var dateFormatter: SXDateFormatter
    /// The formatter used by this Endpoint to serialize each Log Entry to a string.
    open var entryFormatter: SXEntryFormatter
    /// This Endpoint requires a newline character appended to each serialized Log Entry string.
    public let requiresNewlines: Bool = true

    /// The actual output engine.
    fileprivate let writer: SXConsoleWriter

    /**
     *  Initialize a Console Endpoint.
     *
     *  A synchronous Console Endpoint will write each Entry to the console before continuing with application
     *  execution, which makes debugging much easier. An asynchronous Console Endpoint may continue execution before
     *  every Entry is written to the console, which will improve performance.
     *
     *  - Parameters:
     *      - synchronous: Indicates whether the application should wait for each Entry to be printed
     *                     to the console before continuing execution. Defaults to `true`.
     *      - minimumPriorityLevel: The minimum Priority Level a Log Entry must meet to be accepted by this
     *                              Endpoint. Defaults to `.All`.
     *      - dateFormatter: The formatter used by this Endpoint to serialize a Log Entry’s `dateTime`
     *                                    property to a string. Defaults to `.standardFormatter()`.
     *      - entryFormatter: The formatter used by this Endpoint to serialize each Log Entry to a string.
     *                                    Defaults to `.standardFormatter()`.
     */
    public init(
        synchronous: Bool = true,
        minimumPriorityLevel: SXPriorityLevel = .all,
        dateFormatter: SXDateFormatter = SXDateFormatter.standardFormatter(),
        entryFormatter: SXEntryFormatter = SXEntryFormatter.standardFormatter()
    ) {
        self.minimumPriorityLevel = minimumPriorityLevel
        self.dateFormatter = dateFormatter
        self.entryFormatter = entryFormatter

        switch synchronous {
        case true:
            self.writer = SXSynchronousConsoleWriter()
        case false:
            self.writer = SXAsynchronousConsoleWriter()
        }
    }

    /// Writes a serialized Log Entry string to the console (`stderr`).
    open func write(_ string: String) {
        guard let data = string.data(using: String.Encoding.utf8) else {
            assertionFailure("Failure to create data from entry string")
            return
        }
        self.writer.writeData(data)
    }

}


//MARK: Console Writers

/// A private console writer that facilitates synchronous output.
private class SXSynchronousConsoleWriter: SXConsoleWriter {

    /// The console's (`stderr`) file handle.
    fileprivate let handle = FileHandle.standardError

    /// Clean up.
    deinit { self.handle.closeFile() }

    /// Writes the data to the console (`stderr`).
    fileprivate func writeData(_ data: Data) {
        self.handle.write(data)
    }

}


/// A private console writer that facilitates asynchronous output.
private class SXAsynchronousConsoleWriter: SXConsoleWriter {
//TODO: open a dispatch IO channel to stderr instead of one-off writes?

    /// Writes the data to the console (`stderr`).
    fileprivate func writeData(_ data: Data) {
        let dispatchData = data.withUnsafeBytes({
            DispatchData(bytesNoCopy: UnsafeRawBufferPointer(start: $0, count: data.count))
        })

        DispatchIO.write(toFileDescriptor: STDERR_FILENO, data: dispatchData, runningHandlerOn: SX_STENOGRAPHER_QUEUE, handler: { _, _ in })
    }

}
