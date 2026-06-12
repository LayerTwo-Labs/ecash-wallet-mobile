// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Observation
import SkipFuse   // @Observable must drive the Android (Compose) UI in Fuse
import WalletService

/// Drives the Send flow: enter (address + keypad amount + fee tier) → review → broadcast →
/// sent/failed. Platform-agnostic and testable: it depends only on injected closures (AppState
/// wires them to `WalletManager`), so the state machine never touches BDK directly.
///
/// String-editing rules live in `WalletService.AmountEntry` (parity-tested); this type owns the
/// step machine and validation.
@MainActor
@Observable
final class SendViewModel {
    enum Step: Equatable {
        case entering
        case reviewing
        case broadcasting
        case sent
        case failed(String)   // user-safe message (already scrubbed by WalletError)
    }

    /// v1 fee tiers — sane fixed defaults for the testnet-class networks.
    /// TODO(send-v2): fetch live estimates from the backend per CLAUDE.md §6 (never zero).
    enum FeeTier: String, CaseIterable, Hashable {
        case slow, normal, fast

        var label: String {
            switch self {
            case .slow: return "Slow"
            case .normal: return "Normal"
            case .fast: return "Fast"
            }
        }

        var feeRate: FeeRate {
            switch self {
            case .slow: return FeeRate(satPerVByte: 1)
            case .normal: return FeeRate(satPerVByte: 2)
            case .fast: return FeeRate(satPerVByte: 5)
            }
        }
    }

    // Wallet context, fixed at presentation time (the Send sheet is per-selected-wallet).
    let balance: Amount
    let unitLabel: String
    let networkDisplayName: String
    let isMainnet: Bool

    // Entry state. `addressText` accepts a bare address or a BIP21 URI (parsed at review).
    var addressText = ""
    private(set) var amountText = ""
    var tier: FeeTier = .normal
    private(set) var step: Step = .entering

    // Normalized at review() — what confirmSend() actually sends and the review screen shows.
    private(set) var reviewAddress = ""
    private(set) var reviewAmount: Amount = .zero

    private let send: (_ address: String, _ amount: Amount, _ feeRate: FeeRate) async throws -> WalletTx
    private let onSent: @MainActor (WalletTx) -> Void

    init(balance: Amount,
         unitLabel: String,
         networkDisplayName: String,
         isMainnet: Bool,
         send: @escaping (_ address: String, _ amount: Amount, _ feeRate: FeeRate) async throws -> WalletTx,
         onSent: @escaping @MainActor (WalletTx) -> Void) {
        self.balance = balance
        self.unitLabel = unitLabel
        self.networkDisplayName = networkDisplayName
        self.isMainnet = isMainnet
        self.send = send
        self.onSent = onSent
    }

    // MARK: - Keypad

    func tapDigit(_ digit: Int) {
        amountText = AmountEntry.appendDigit(amountText, digit: digit)
    }

    func tapDot() {
        amountText = AmountEntry.appendDot(amountText)
    }

    func tapBackspace() {
        amountText = AmountEntry.backspace(amountText)
    }

    /// Fill the full spendable balance. BDK subtracts the fee at build time, so a literal
    /// max-send can fail with insufficient-funds — that error surfaces actionably on confirm.
    /// TODO(send-v2): true max via TxBuilder drain.
    func tapMax() {
        amountText = balance.formattedCoin()
    }

    // MARK: - Validation

    var amount: Amount? { Amount.fromCoin(amountText) }

    /// Amount shown above the keypad ("0" placeholder when empty).
    var displayAmountText: String { amountText.isEmpty ? "0" : amountText }

    var amountExceedsBalance: Bool {
        guard let amount else { return false }
        return amount.sats > balance.sats
    }

    var canReview: Bool {
        guard let amount else { return false }
        return amount.sats > 0
            && !amountExceedsBalance
            && !addressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Steps

    /// Parse + normalize the entry and advance to the review step. A BIP21 URI's address is
    /// unwrapped here; if it carries an amount and the user hasn't typed one, the URI's is used.
    func review() {
        guard step == .entering else { return }
        guard let parsed = BIP21.parse(addressText) else { return }
        reviewAddress = parsed.address
        if let uriAmount = parsed.amount, amountText.isEmpty {
            amountText = uriAmount.formattedCoin()
        }
        guard canReview, let amount else { return }
        reviewAmount = amount
        step = .reviewing
    }

    func backToEntry() {
        if step == .reviewing { step = .entering }
        if case .failed = step { step = .entering }
    }

    /// Broadcast (off the main actor via the injected async closure), then hand the optimistic
    /// pending tx to AppState. Golden Rule §7: only reachable from the review step the user
    /// explicitly confirmed, which states network + recipient + amount + fee.
    func confirmSend() async {
        guard step == .reviewing else { return }
        step = .broadcasting
        do {
            let tx = try await send(reviewAddress, reviewAmount, tier.feeRate)
            onSent(tx)
            step = .sent
        } catch let error as WalletError {
            step = .failed(error.userMessage)
        } catch {
            step = .failed("Couldn't send. Please try again.")
        }
    }
}
