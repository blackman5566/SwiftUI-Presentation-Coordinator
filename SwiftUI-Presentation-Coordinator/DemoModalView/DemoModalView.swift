//
//  DemoModalView.swift
//  SwiftUI-Presentation-Coordinator
//
//  Created by 許佳豪 on 2025/12/26.
//

import SwiftUI

struct DemoModalView: View {
    let title: String
    let level: Int
    let isPresented: Binding<Bool>

    /// 如果你用 .alert (transparent overlay)，可以用這個做一點視覺提示
    var isOverlayStyle: Bool = false

    /// 讓使用者一進來就知道可以按哪個按鈕串三層
    var showNestedGuide: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())

            Text("Level: \(level)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if showNestedGuide {
                Text("Try: Open BottomSheet → Open Alert → Close Level 1")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Divider().padding(.vertical, 6)

            // MARK: - Present next level
            VStack(spacing: 10) {
                Button("Open Next as Sheet (Level \(level + 1))") {
                    Coordinator.shared.present(type: .sheet) { nextPresented in
                        DemoModalView(
                            title: "Sheet - Level \(level + 1)",
                            level: level + 1,
                            isPresented: nextPresented
                        )
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Open Next as Bottom Sheet (Level \(level + 1))") {
                    Coordinator.shared.present(type: .bottomSheet) { nextPresented in
                        DemoModalView(
                            title: "Bottom Sheet - Level \(level + 1)",
                            level: level + 1,
                            isPresented: nextPresented
                        )
                    }
                }
                .buttonStyle(.bordered)

                Button("Open Next as Alert Overlay (Level \(level + 1))") {
                    Coordinator.shared.present(type: .alert) { nextPresented in
                        DemoModalView(
                            title: "Alert Overlay - Level \(level + 1)",
                            level: level + 1,
                            isPresented: nextPresented,
                            isOverlayStyle: true
                        )
                    }
                }
                .buttonStyle(.bordered)
            }

            Divider().padding(.vertical, 6)

            // MARK: - Close
            HStack(spacing: 10) {
                Button(role: .cancel) {
                    // ✅ 關閉「自己這一層」
                    isPresented.wrappedValue = false
                } label: {
                    Text("Close This Level")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    // ✅ 全清（Level 0）
                    Coordinator.shared.onRouteDismissed(at: 0)
                } label: {
                    Text("Close All")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isOverlayStyle ? Color.black.opacity(0.75) : Color(.systemBackground))
        )
        .foregroundStyle(isOverlayStyle ? Color.white : Color.primary)
        .padding(isOverlayStyle ? 24 : 0)
    }
}
