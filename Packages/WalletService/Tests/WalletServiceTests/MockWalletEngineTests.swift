// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import XCTest
@testable import WalletService

/// Confirms the mock behaves deterministically — fixtures, error injection, and call tracking —
/// so view-model tests built on it (later milestones) are trustworthy.
final class MockWalletEngineTests: XCTestCase {

    func testReturnsFixtures() throws {
        let mock = MockWalletEngine(network: .signet, balance: Amount(sats: Int64(42)))
        XCTAssertEqual(mock.network, WalletNetwork.signet)
        XCTAssertEqual(try mock.balance().sats, Int64(42))
        XCTAssertEqual(try mock.nextReceiveAddress().address, "tb1qmockreceiveaddress")
    }

    func testThrowsInjectedError() {
        // do/catch instead of XCTAssertThrowsError, which SkipUnit's XCTest subset lacks.
        let mock = MockWalletEngine()
        mock.errorToThrow = .syncFailed

        var balanceThrew = false
        do { _ = try mock.balance() } catch { balanceThrew = true }
        XCTAssertTrue(balanceThrew)

        var addressThrew = false
        do { _ = try mock.nextReceiveAddress() } catch { addressThrew = true }
        XCTAssertTrue(addressThrew)
    }

    func testSendTracksArgsAndReturnsOutgoingPending() throws {
        let mock = MockWalletEngine()
        let tx = try mock.send(to: "tb1qdest",
                               amount: Amount(sats: Int64(1000)),
                               feeRate: FeeRate(satPerVByte: Int64(5)))
        XCTAssertEqual(mock.lastSendAddress, "tb1qdest")
        XCTAssertEqual(mock.lastSendAmount?.sats, Int64(1000))
        XCTAssertEqual(tx.netSats, Int64(-1000))
        XCTAssertFalse(tx.isReceived)
        XCTAssertTrue(tx.isRBF)
        XCTAssertEqual(tx.confirmations, Int32(0))
    }

    func testSyncTracksCallCount() async throws {
        let mock = MockWalletEngine()
        try await mock.sync()
        try await mock.sync()
        XCTAssertEqual(mock.syncCallCount, 2)
    }
}
