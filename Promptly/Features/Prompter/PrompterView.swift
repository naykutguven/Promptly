//
//  PrompterView.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import SwiftUI

struct PrompterView: View {
    let windowModel: PrompterWindowModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                PrompterHeaderView(title: "Sample Title")

                HStack(spacing: 0) {
                    control(
                        windowModel.isLocked ? "Unlock Prompter" : "Lock Prompter",
                        symbol: windowModel.isLocked ? "lock.fill" : "lock.open.fill",
                        id: "prompter.lock") {
                            windowModel.isLocked.toggle()
                        }

                    control(
                        windowModel.isAttachedToNotch ? "Detach from Notch" : "Attach to Notch",
                        symbol: windowModel.isAttachedToNotch ? "arrow.up.to.line" : "arrow.down.to.line",
                        id: "prompter.attach",
                        action: windowModel.moveNearNotch
                    )

                    control(
                        "Hide Prompter",
                        symbol: "xmark",
                        id: "prompter.hide",
                        action: windowModel.hide
                    )
                }
                .padding(.horizontal, 12)

            }
            .foregroundStyle(.white)
            .frame(height: PrompterWindowLayoutConstants.collapsedHeight)

            ScrollView {
                Text("Your prompter content goes here...")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(height: 252)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .frame(
            minWidth: 360,
            alignment: .topLeading
        )
        .background(.black)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: windowModel.isAttachedToNotch ? 0 : 24,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24,
                topTrailingRadius: windowModel.isAttachedToNotch ? 0 : 24
            )
        )
        .windowResizeAnchor(.topLeading)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func control(
        _ title: LocalizedStringKey,
        symbol: String,
        id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).labelStyle(.iconOnly)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(Text(title))
        .accessibilityIdentifier(id)
    }
}

#Preview {
    PrompterView(windowModel: PrompterWindowModel())

}

struct PrompterHeaderView: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: PrompterWindowLayoutConstants.collapsedHeight)
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())
        .allowsWindowActivationEvents()
        .help("Drag to move Prompter")
    }
}
