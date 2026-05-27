//
//  SupabaseConfig.swift
//  chorra
//
//  Created by Codex on 27/5/2026.
//

import Foundation
import Supabase

enum SupabaseConfigError: LocalizedError {
    case missingValue(String)
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let key):
            return "Missing \(key). Set \(key) in the target build settings or launch environment."
        case .invalidURL(let value):
            return "Invalid Supabase URL: \(value)"
        }
    }
}

struct SupabaseConfig {
    let url: URL
    let publishableKey: String

    static func load() throws -> SupabaseConfig {
        let urlString = try requiredValue(for: "SUPABASE_URL")
        let publishableKey = try requiredValue(for: "SUPABASE_PUBLISHABLE_KEY")

        guard let url = URL(string: urlString), url.scheme != nil, url.host != nil else {
            throw SupabaseConfigError.invalidURL(urlString)
        }

        return SupabaseConfig(url: url, publishableKey: publishableKey)
    }

    func makeClient() -> SupabaseClient {
        SupabaseClient(supabaseURL: url, supabaseKey: publishableKey)
    }

    private static func requiredValue(for key: String) throws -> String {
        let environmentValue = ProcessInfo.processInfo.environment[key]
        let bundleValue = Bundle.main.object(forInfoDictionaryKey: key) as? String
        let value = environmentValue ?? bundleValue
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmedValue.isEmpty || trimmedValue.hasPrefix("$(") {
            throw SupabaseConfigError.missingValue(key)
        }

        return trimmedValue
    }
}
