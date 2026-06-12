// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import WalletService

/// The Send flow, presented as a full-screen cover from Home. Steps through the
/// `SendViewModel` state machine: enter (address + keypad amount + fee tier) → review
/// (network + recipient + amount + fee — Golden Rule §7) → broadcasting → sent/failed.
struct SendScreen: View {
    @Environment(\.dismiss) var dismiss
    @State var vm: SendViewModel   // not `private` — Fuse bridges @State (skip-fuse rule)

    init(viewModel: SendViewModel) {
        _vm = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bg0.ignoresSafeArea()
                content
            }
            .navigationTitle("Send")
            .toolbar {
                // `.primaryAction` (not `.topBarTrailing`/`.cancellationAction`) — the placement
                // proven cross-platform in this codebase (ReceiveScreen) and macOS-safe for Skip.
                ToolbarItem(placement: .primaryAction) {
                    if vm.step == .entering {
                        Button { dismiss() } label: { Text("Cancel") }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.step {
        case .entering:
            entry
        case .reviewing:
            review
        case .broadcasting:
            VStack(spacing: Theme.Space.x4) {
                ProgressView()
                Text("Broadcasting…")
                    .textStyle(.sm)
                    .foregroundStyle(Theme.Colors.text1)
            }
        case .sent:
            sent
        case .failed(let message):
            failed(message)
        }
    }

    // MARK: - Entry

    private var entry: some View {
        VStack(spacing: Theme.Space.x4) {
            NetworkBadge(name: vm.networkDisplayName, isMainnet: vm.isMainnet)

            // Recipient: paste a bare address or a BIP21 URI. Mono, like all addresses.
            TextField("Address or payment URI", text: $vm.addressText)
                .font(.jbMono(14, .regular))
                .foregroundStyle(Theme.Colors.text0)
                .autocorrectionDisabled()
                .noAutocapitalization()
                .padding(Theme.Space.x3)
                .background(Theme.Colors.bg2, in: RoundedRectangle(cornerRadius: Theme.Radius.md))

            Spacer()

            // Amount, JetBrains Mono — red when it exceeds the spendable balance.
            VStack(spacing: Theme.Space.x1) {
                Text(vm.displayAmountText)
                    .font(.jbMono(40, .medium))
                    .foregroundStyle(vm.amountExceedsBalance ? Theme.Colors.negative : Theme.Colors.text0)
                Text(vm.unitLabel)
                    .textStyle(.overline)
                    .foregroundStyle(Theme.Colors.text2)
                Button { vm.tapMax() } label: {
                    Text("Max: \(vm.balance.formattedCoin())")
                        .textStyle(.xs)
                        .foregroundStyle(Theme.Colors.accent)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            feeTierPicker

            Keypad(onDigit: { vm.tapDigit($0) },
                   onDot: { vm.tapDot() },
                   onBackspace: { vm.tapBackspace() })

            WalletButton(title: "Review") {
                vm.review()
            }
            .disabled(!vm.canReview)
            .opacity(vm.canReview ? 1 : 0.4)
        }
        .padding(Theme.Space.gutter)
    }

    private var feeTierPicker: some View {
        Picker("Fee", selection: $vm.tier) {
            ForEach(SendViewModel.FeeTier.allCases, id: \.self) { tier in
                Text(tier.label).tag(tier)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Review

    private var review: some View {
        VStack(spacing: Theme.Space.x5) {
            NetworkBadge(name: vm.networkDisplayName, isMainnet: vm.isMainnet)

            VStack(spacing: Theme.Space.x1) {
                Text(vm.reviewAmount.formattedCoin())
                    .font(.jbMono(36, .medium))
                    .foregroundStyle(Theme.Colors.text0)
                Text(vm.unitLabel)
                    .textStyle(.overline)
                    .foregroundStyle(Theme.Colors.text2)
            }

            VStack(alignment: .leading, spacing: Theme.Space.x3) {
                reviewRow(label: "To", value: vm.reviewAddress)
                reviewRow(label: "Network", value: vm.networkDisplayName)
                reviewRow(label: "Fee", value: "\(vm.tier.label) · \(vm.tier.feeRate.satPerVByte) sat/vB")
                Text("The network fee is set by rate; the exact fee is deducted at send.")
                    .textStyle(.xs)
                    .foregroundStyle(Theme.Colors.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Space.x4)
            .background(Theme.Colors.bg1, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )

            Spacer()

            WalletButton(title: "Confirm send") {
                Task { await vm.confirmSend() }
            }
            WalletButton(title: "Back", kind: .secondary) {
                vm.backToEntry()
            }
        }
        .padding(Theme.Space.gutter)
    }

    private func reviewRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .textStyle(.overline)
                .foregroundStyle(Theme.Colors.text2)
            Text(value)
                .font(.jbMono(14, .regular))
                .foregroundStyle(Theme.Colors.text0)
        }
    }

    // MARK: - Terminal states

    private var sent: some View {
        VStack(spacing: Theme.Space.x4) {
            Image(icon: Icon.check)
                .resizable().scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundStyle(Theme.Colors.positive)
            Text("Sent")
                .textStyle(.h2)
                .foregroundStyle(Theme.Colors.text0)
            Text("Your transaction is broadcast and pending confirmation.")
                .textStyle(.sm)
                .foregroundStyle(Theme.Colors.text1)
                .multilineTextAlignment(.center)
            WalletButton(title: "Done") {
                dismiss()
            }
        }
        .padding(Theme.Space.gutter)
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: Theme.Space.x4) {
            Image(icon: Icon.caution)
                .resizable().scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundStyle(Theme.Colors.negative)
            Text(message)
                .textStyle(.sm)
                .foregroundStyle(Theme.Colors.text0)
                .multilineTextAlignment(.center)
            WalletButton(title: "Back") {
                vm.backToEntry()
            }
        }
        .padding(Theme.Space.gutter)
    }
}
