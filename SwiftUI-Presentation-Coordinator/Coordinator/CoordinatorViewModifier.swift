//
//  CoordinatorViewModifier.swift
//  SwiftUI_Wallet
//
//  Created by 許佳豪 on 2025/12/19.
//

import SwiftUI

// MARK: - CoordinatorViewModifier (Recursive modal host)

/// CoordinatorViewModifier
///
/// ✅ 目的：
/// 把 `Coordinator.routeStack` 轉成真正的 SwiftUI modal 呈現（sheet / bottomSheet / alert overlay）
///
/// ✅ 核心概念：
/// - routeStack 的 index 就是「level」
/// - 這個 modifier 每一層只負責「level 這一層」的呈現
/// - 透過遞迴 `.modifier(CoordinatorViewModifier(level: level + 1))`
///   讓下一層 modal 由下一層 modifier 接手
///
/// 👉 這個遞迴設計的好處：
/// - 能自然支援「多層 modal 疊加」
/// - 每一層的 dismiss 規則一致（dismiss level N → remove N...top）
/// - View 本身不用塞一堆 `@State` 管理呈現狀態
struct CoordinatorViewModifier: ViewModifier {

    /// 觀察 Coordinator 的 routeStack
    @ObservedObject private var coordinator = Coordinator.shared

    /// 目前這個 modifier 負責的層級（對應 routeStack index）
    private let level: Int

    /// bottomSheet 會動態量高度，所以需要記住目前高度
    @State private var sheetHeight: CGFloat? = nil

    init(level: Int = 0) {
        self.level = level
    }

    func body(content: Content) -> some View {
        // ✅ 三種 presentation 類型依序包上去：
        // content
        //   -> sheet
        //      -> bottomSheet
        //         -> alert overlay
        //
        // 注意：這三個 wrapper 都是「針對同一個 level」。
        // 實際哪個會出現，取決於 routeStack[level].type
        let normalSheet = normalSheet(content)
        let bottomSheet = bottomSheet(normalSheet)
        let alertCover = alertCover(bottomSheet)
        return alertCover
    }
}

// MARK: - Level host implementations

private extension CoordinatorViewModifier {

    // MARK: 1) Normal Sheet

    /// 處理 RouteType.sheet
    ///
    /// ✅ isPresented binding 的來源：
    /// - get: coordinator.hasSheet(at: level)
    /// - set: 當 sheet 被使用者手勢關閉時（newValue = false），呼叫 coordinator.onRouteDismissed(at: level)
    ///
    /// ✅ 重點：
///  內容 view 也會收到同一個 isPresented binding，
///  讓內容可以自行 `isPresented.wrappedValue = false` 來關閉這一層。
    func normalSheet(_ content: Content) -> some View  {
        content.sheet(isPresented: Binding<Bool>(
            get: { coordinator.hasSheet(at: level) },

            set: { newValue in
                if !newValue {
                    // 使用者 swipe down / 系統關閉 sheet
                    // → 依 stack 規則移除 level...top
                    coordinator.onRouteDismissed(at: level)
                }
            }
        )) {
            // 取得這一層 route 的內容並呈現
            if let route = coordinator.route(at: level) {

                route.content(isPresented: Binding<Bool>(
                    get: { coordinator.hasSheet(at: level) },
                    set: { newValue in
                        if !newValue {
                            coordinator.onRouteDismissed(at: level)
                        }
                    }
                ))
                // ✅ 遞迴：下一層 modal 由 level+1 的 modifier 負責
                // 這一行就是多層 modal 能成立的關鍵
                .modifier(CoordinatorViewModifier(level: level + 1))
            }
        }
    }

    // MARK: 2) Bottom Sheet

    /// 處理 RouteType.bottomSheet
    ///
    /// 這裡用 `.sheet` + `.presentationDetents` 做 bottomSheet
    /// 特色：
///  - 用 PreferenceKey + GeometryReader 量內容高度，讓 sheet 高度貼合內容
    func bottomSheet<V: View>(_ content: V) -> some View {
        content.sheet(isPresented: Binding(
            get: { coordinator.hasBottomSheet(at: level) },
            set: { if !$0 { coordinator.onRouteDismissed(at: level) } }
        )) {
            if let route = coordinator.route(at: level) {
                ZStack {
                    // 背景只是 demo / 占位
                    Color.secondary.ignoresSafeArea()

                    route.content(isPresented: Binding(
                        get: { coordinator.hasBottomSheet(at: level) },
                        set: { if !$0 { coordinator.onRouteDismissed(at: level) } }
                    ))
                    // 避免內容被壓縮，讓高度量測更準
                    .fixedSize(horizontal: false, vertical: true)

                    // ✅ 量內容高度 → 用 InnerHeightPreferenceKey 往外傳
                    .overlay {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: InnerHeightPreferenceKey.self,
                                value: geo.size.height
                            )
                        }
                    }

                    // ✅ 接收高度變化 → 更新 sheetHeight → 讓 detent 跟著動
                    .onPreferenceChange(InnerHeightPreferenceKey.self) { h in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            sheetHeight = h
                        }
                    }
                }

                // ✅ detent 高度：
                // - 若量到高度就用 .height(h)
                // - 若尚未量到（nil），先用 .medium 當 fallback，避免 0 高度閃動
                .presentationDetents([sheetHeight.map { .height($0) } ?? .medium])

                // ✅ 遞迴：讓下一層 modal 可以繼續疊上去
                .modifier(CoordinatorViewModifier(level: level + 1))
            }
        }
    }

    // MARK: 3) Alert Overlay (Transparent Full Screen)

    /// 處理 RouteType.alert
    ///
    /// 這裡用 `transparentFullScreenCover` 的原因：
    /// - SwiftUI 原生 fullScreenCover 預設背景不透明，很難做出「透明 overlay」
///  - TransparentFullScreen.swift 用 UIKit hack 讓背景透明，
///    讓你可以做「半透明遮罩 + 中間卡片」的 alert/popup
    func alertCover<V: View>(_ content: V) -> some View {
        content.transparentFullScreenCover(isPresented: Binding(
            get: { coordinator.hasAlert(at: level) },
            set: { if !$0 { coordinator.onRouteDismissed(at: level) } }
        )) {
            if let route = coordinator.route(at: level) {
                route.content(isPresented: Binding(
                    get: { coordinator.hasAlert(at: level) },
                    set: { if !$0 { coordinator.onRouteDismissed(at: level) } }
                ))
                // ✅ 遞迴：alert 上面也可以再疊 modal（看需求）
                .modifier(CoordinatorViewModifier(level: level + 1))
            }
        }
    }
}
