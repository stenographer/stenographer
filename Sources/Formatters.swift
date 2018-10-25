// Formatters.swift
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

//MARK: Date Formatter

/**
 *  Instances of `SXDateFormatter` create string representations of `NSDate` objects. There are several built-in
 *  formats available, or a custom format can be specified in the same format as in `NSDateFormatter` objects.
 */
open class SXDateFormatter {

    /// Converts `NSDate` objects into datetime strings in the format `yyyy-MM-dd HH:mm:ss.SSS`, using the UTC timezone.
    open class func standardFormatter() -> Self {
        return self.init(formatString: "yyyy-MM-dd HH:mm:ss.SSS")
    }

    /// Converts `NSDate` objects into time-only strings in the format `HH:mm:ss.SSS`, using the UTC timezone.
    open class func timeOnlyFormatter() -> Self {
        return self.init(formatString: "HH:mm:ss.SSS")
    }

    /// Converts `NSDate` objects into date-only strings in the format `yyyy-MM-dd`, using the UTC timezone.
    open class func dateOnlyFormatter() -> Self {
        return self.init(formatString: "yyyy-MM-dd")
    }

    /// Converts `NSDate` objects into strings following the ISO 8601 combined datetime format, using the UTC timezone.
    open class func ISO8601DateTimeFormatter() -> Self {
        return self.init(formatString: "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ")
    }

    /// The internal formatting engine.
    fileprivate let dateFormatter: DateFormatter

    /**
     *  Creates a new `SXDateFormatter` instance.
     *
     *  - Parameters:
     *      - formatString: The desired format string used to convert dates to strings. Uses the same format string as `NSDateFormatter.dateFormat`.
     *
     *      - timezone: An `NSTimeZone` instance representing the desired time zone of the date string output. Defaults to UTC.
     */
    public required init(formatString: String, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.timeZone = timeZone
        self.dateFormatter.dateFormat = formatString
    }

    /**
     *  Converts an `NSDate` object into a string using the date formatter's settings.
     *
     *  - Parameter date: The `NSDate` instance to be converted.
     *
     *  - Returns: A string representation of the date, based on the formatter's settings.
     */
    internal func stringFromDate(_ date: Date) -> String {
        return self.dateFormatter.string(from: date)
    }
}

//MARK: Entry Formatter

/**
 *  Instances of SXEntryFormatter create string representations of `SXLogEntry` objects. There are several built-in
 *  formats available, or a custom format can be specified as a closure of the type `(SXLogEntry) -> String`.
 */
open class SXEntryFormatter {
    // We're using format strings here instead of string interpolation because the latter currently leaks memory. See:
    // https://github.com/logkit/logkit/issues/26
    // https://bugs.swift.org/browse/SR-1728

    /// Converts `SXLogEntry` objects into strings in a standard format that contains basic debugging information.
    open class func standardFormatter() -> Self {
        return self.init {
            e in String(format: "%@ [%@] %@ <%@:%d> %@",e.dateTime, e.level.uppercased(),
                        e.functionName, e.fileName, e.lineNumber, e.message)
        }
    }

    /// Converts `SXLogEntry` objects into strings in a long format that contains detailed debugging information.
    open class func longFormatter() -> Self {
        return self.init {
            e in String(format: "%@ (%f) [%@] {thread: %@ '%@' main: %@} %@ <%@:%d.%d> %@",
                        e.dateTime, e.timestamp, e.level.uppercased(), e.threadID, e.threadName,
                        e.isMainThread ? "true" : "false", e.functionName, e.fileName, e.lineNumber,
                        e.columnNumber, e.message)
        }
    }

    /// Converts `SXLogEntry` objects into strings in a short format that contains minimal debugging information.
    open class func shortFormatter() -> Self {
        return self.init {
            e in String(format: "%@ [%@] %@", e.dateTime, e.level.uppercased(), e.message)
        }
    }

    /// Converts `SXLogEntry` objects into strings in a short format that contains only the logged message.
    open class func messageOnlyFormatter() -> Self {
        return self.init {
            e in e.message
        }
    }

    /// The internal formatting engine.
    fileprivate let entryFormatter: (_ entry: SXLogEntry) -> String

    /**
     *  Creates a new `SXEntryFormatter` instance.
     *
     *  - Parameter _: A closure that accepts an `SXLogEntry` and Returns a `String`.
     */
    public required init(_ closure: @escaping (SXLogEntry) -> String) {
        self.entryFormatter = closure
    }

    /**
     *  Converts an `SXLogEntry` object into a string using the entry formatter's settings.
     *
     *  - Parameters:
     *      - entry:         The `SXLogEntry` instance to be converted.
     *
     *      - appendNewline: Indicates whether a newline character should be appended to the ending of the converted Entry's string.
     *
     *  - Returns: A string representation of the Log Entry, based on the formatter's settings.
     */
    internal func stringFromEntry(_ entry: SXLogEntry, appendNewline: Bool) -> String {
        return appendNewline ? entryFormatter(entry) + "\n" : entryFormatter(entry)
    }
}

extension SXEntryFormatter {

    /// An internal error indicating that the serialized JSON data could not be decoded into a string.
    fileprivate enum EntryFormattingError: Error { case decodingError }

    /// Converts `SXLogEntry` objects into JSON strings, representing a dictionary of all Entry properties.
    internal class func jsonFormatter() -> Self {
        return self.init({
            do {
                // TODO: this "object" is a bit of a hack, so that later we can enable uploading multiple enties at once.
                let object = ["entries": [$0.asMap()]]
                let data = try JSONSerialization.data(withJSONObject: object, options: [])
                guard let json = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else {
                    throw EntryFormattingError.decodingError
                }

                return json as String
            } catch {
                assertionFailure("Log entry could not be serialized to JSON")

                return "{\"error\": \"serialization_error\"}"
            }
        })
    }
}
