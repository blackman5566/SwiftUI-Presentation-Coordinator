//
//  TransparentFullScreen.swift
//  SwiftUI_Wallet
//
//  Created by 許佳豪 on 2025/12/19.
//

import SwiftUI

// MARK: - Transparent Full Screen Cover

/// TransparentFullScreenModifier
///
/// ✅ 目的：
/// SwiftUI 的 `fullScreenCover` 預設背景會是「不透明」
/// （通常是系統的 UIHostingController 背景色）。
///
/// 如果你想做這種 UI：
/// - 半透明遮罩（dim）
/// — 中間一張卡片 / popup
/// - 背後的畫面仍然可見
///
/// 你會發現：只用 SwiftUI 很難把 fullScreenCover 背景變透明。
///
/// ✅ 做法：
/// 1) 仍然使用 `.fullScreenCover` 來呈現
/// 2) 在 cover 的內容後面加上一個 `UIViewRepresentable`
/// 3) 在 UIKit view hierarchy 裡把 hosting controller 的背景改成 `.clear`
///
/// ⚠️ 注意：
/// 這屬於 UIKit hack（依賴 view hierarchy），
/// 若 Apple 內部結構變更，可能需要調整 superview 層級。
private struct TransparentFullScreenModifier<FullScreenContent: View>: ViewModifier {

    /// 控制 fullScreenCover 顯示/關閉
    @Binding var isPresented: Bool

    /// 真正要顯示的 overlay 內容
    let fullScreenContent: () -> FullScreenContent

    func body(content: Content) -> some View {
        content
            // ✅ 目的：減少 fullScreenCover 切換時的閃動/動畫副作用
            // 有些情況下透明背景切換會出現一瞬間的黑底或動畫不一致，
            // 這裡在狀態變動時先暫時關掉 UIKit animations。
            .onChange(of: isPresented) { _, _ in
                UIView.setAnimationsEnabled(false)
            }

            // ✅ 仍然使用 fullScreenCover（系統負責呈現/手勢/生命週期）
            .fullScreenCover(
                isPresented: $isPresented,
                content: {
                    ZStack {
                        fullScreenContent()
                    }

                    // ✅ 關鍵：把 hosting view hierarchy 的背景清掉
                    .background(FullScreenCoverBackgroundRemovalView())

                    // ✅ 避免全域關動畫後忘記打開
                    .onAppear {
                        if !UIView.areAnimationsEnabled {
                            UIView.setAnimationsEnabled(true)
                        }
                    }
                    .onDisappear {
                        if !UIView.areAnimationsEnabled {
                            UIView.setAnimationsEnabled(true)
                        }
                    }
                }
            )
    }
}

// MARK: - UIKit Background Removal Helper

/// FullScreenCoverBackgroundRemovalView
///
/// ✅ 這個 UIViewRepresentable 的存在目的：
/// 取得 fullScreenCover 底下 UIKit view 的 superview，
/// 然後把背景改成透明（.clear）。
///
/// 為什麼放在 `didMoveToWindow`？
/// - 只有當 view 被加到 window 之後，superview / hierarchy 才是穩定可操作的。
private struct FullScreenCoverBackgroundRemovalView: UIViewRepresentable {

    /// 這個 UIView 會被插入 SwiftUI hierarchy
    /// 一旦被加到 window，就可以拿到 UIKit 的 superview 結構。
    private class BackgroundRemovalView: UIView {

        override func didMoveToWindow() {
            super.didMoveToWindow()

            // ✅ fullScreenCover 通常是：
            // BackgroundRemovalView
            //   -> UIHostingView（SwiftUI content 容器）
            //     -> UITransitionView / UIKit container（系統管理）
            //
            // 把「更外層」容器背景清成透明，才能讓 fullScreenCover 背景看起來透明。
            //
            // ⚠️ 這邊依賴 superview 層級（可能因 iOS 版本而變）
            superview?.superview?.backgroundColor = .clear
        }
    }

    func makeUIView(context _: Context) -> UIView {
        BackgroundRemovalView()
    }

    func updateUIView(_: UIView, context _: Context) {
        // no-op
    }
}

// MARK: - Public API

extension View {

    /// 對外 API：透明 fullScreenCover
    ///
    /// 用法：
    /// ```swift
    /// @State var show = false
    ///
    /// Button("Show") { show = true }
    ///   .transparentFullScreenCover(isPresented: $show) {
    ///     MyOverlayView()
    ///   }
    /// ```
    ///
    /// ✅ 適合用途：
    /// - 自訂 Alert / Popup
    /// - 半透明遮罩 + 中央卡片
    /// - 需要 full screen 行為但背景要透明
    func transparentFullScreenCover(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        modifier(
            TransparentFullScreenModifier(
                isPresented: isPresented,
                fullScreenContent: content
            )
        )
    }
}
