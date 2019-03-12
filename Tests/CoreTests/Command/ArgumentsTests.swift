//
//  ArgumentsTests.swift
//  StyleSource
//
//  Created by luiz.fernando.silva on 11/03/2019.
//

import XCTest
import Core

class ArgumentsTests: XCTestCase {
    func testDefault() {
        let def = Arguments.default

        XCTAssertFalse(def.alwaysOverride)
        XCTAssertFalse(def.verbose)
    }

    func testParseEmptyArguments() {
        XCTAssertNoThrow(try Arguments.parse(from: []))
    }

    func testParseAlwaysOverride() throws {
        let arguments = try Arguments.parse(from: ["--always-overwrite"])

        XCTAssert(arguments.alwaysOverride)
    }

    func testParseVerbose() throws {
        let arguments = try Arguments.parse(from: ["--verbose"])

        XCTAssert(arguments.verbose)
    }

    func testParseError() throws {
        XCTAssertThrowsError(try Arguments.parse(from: ["--unknown-arg"])) { error in
            XCTAssert((error as? Arguments.ParseError)?.localizedDescription == "Unknown command line argument: --unknown-arg")
        }
    }
}
