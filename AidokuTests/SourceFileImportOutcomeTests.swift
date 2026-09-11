//
//  SourceFileImportOutcomeTests.swift
//  Aidoku
//

import Testing
@testable import Aidoku

@Suite struct SourceFileImportOutcomeTests {
    @Test func cancelledWhenNothingImported() {
        #expect(SourceFileImportOutcome(succeeded: 0, failed: 0) == .none)
    }

    @Test func successWhenEveryFileImports() {
        #expect(SourceFileImportOutcome(succeeded: 1, failed: 0) == .success)
        #expect(SourceFileImportOutcome(succeeded: 3, failed: 0) == .success)
    }

    @Test func failureWhenEveryFileFails() {
        #expect(SourceFileImportOutcome(succeeded: 0, failed: 1) == .allFailed)
        #expect(SourceFileImportOutcome(succeeded: 0, failed: 4) == .allFailed)
    }

    @Test func partialWhenSomeFilesFail() {
        #expect(SourceFileImportOutcome(succeeded: 2, failed: 1) == .partial(failed: 1, total: 3))
        #expect(SourceFileImportOutcome(succeeded: 1, failed: 2) == .partial(failed: 2, total: 3))
    }
}
