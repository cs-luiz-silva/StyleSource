//
//  Arguments.swift
//  StyleSource
//
//  Created by luiz.fernando.silva on 11/03/2019.
//

public struct ArgumentKeys {
    public static var alwaysOverwrite = "--always-overwrite"
    public static var verbose = "--verbose"
}

public struct Arguments {
    public static var `default` = Arguments(alwaysOverride: false, verbose: false)

    public var alwaysOverride: Bool
    public var verbose: Bool
}

extension Arguments {
    public static func parse(from arguments: [String]) throws -> Arguments {
        var output = Arguments.default

        for argument in arguments {
            switch argument {
            case ArgumentKeys.alwaysOverwrite:
                output.alwaysOverride = true

            case ArgumentKeys.verbose:
                output.verbose = true

            default:
                throw ParseError.unknownArgument(argument)
            }
        }

        return output
    }

    public enum ParseError: Error {
        case unknownArgument(String)

        public var localizedDescription: String {
            return description
        }

        var description: String {
            switch self {
            case .unknownArgument(let name):
                return "Unknown command line argument: \(name)"
            }
        }
    }
}
