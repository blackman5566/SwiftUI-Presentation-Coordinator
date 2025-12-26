//
//  ContentView.swift
//  SwiftUI-Presentation-Coordinator
//
//  Created by 許佳豪 on 2025/12/26.
//

import SwiftUI

struct DemoHomeView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {

                Text("Coordinator Demo")
                    .font(.title.bold())

                Text("""
                This demo shows:
                - sheet / bottomSheet / alert (transparent overlay)
                - nested presentation (Level 1 → Level 2 → Level 3)
                - dismiss rule: dismiss Level N removes N and above
                """)
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Divider()

                Button("Open Sheet (Level 1)") {
                    Coordinator.shared.present(type: .sheet) { isPresented in
                        DemoModalView(
                            title: "Sheet - Level 1",
                            level: 1,
                            isPresented: isPresented
                        )
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Open Bottom Sheet (Level 1)") {
                    Coordinator.shared.present(type: .bottomSheet) { isPresented in
                        DemoModalView(
                            title: "Bottom Sheet - Level 1",
                            level: 1,
                            isPresented: isPresented
                        )
                    }
                }
                .buttonStyle(.bordered)

                Button("Open Alert Overlay (Level 1)") {
                    Coordinator.shared.present(type: .alert) { isPresented in
                        DemoModalView(
                            title: "Alert Overlay - Level 1",
                            level: 1,
                            isPresented: isPresented,
                            isOverlayStyle: true
                        )
                    }
                }
                .buttonStyle(.bordered)

                Divider()

                Button("Open Nested Flow (Start with Sheet)") {
                    Coordinator.shared.present(type: .sheet) { isPresented in
                        DemoModalView(
                            title: "Sheet - Level 1 (Start Nested)",
                            level: 1,
                            isPresented: isPresented,
                            showNestedGuide: true
                        )
                    }
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    // ✅ 依照你的 Coordinator 規則：dismiss level 0 → 全清
                    Coordinator.shared.onRouteDismissed(at: 0)
                } label: {
                    Text("Dismiss All")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding()
            .navigationTitle("Demo")
        }
    }
}

#Preview {
    DemoHomeView()
}
