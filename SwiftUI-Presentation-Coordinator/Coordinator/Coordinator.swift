//
//  Coordinator.swift
//  SwiftUI_Wallet
//
//  Created by 許佳豪 on 2025/12/19.
//

import Combine
import Foundation
import SwiftUI

// MARK: - Coordinator (Stack-driven modal presenter)

/// Coordinator
///
/// ✅ 這是一個「用 stack 管理 SwiftUI modal」的 coordinator。
///
/// 核心概念：
/// - 每一次 present，就把一個 `Route` push 進 `routeStack`
/// - `routeStack` 的 index 就是 modal 的「層級 level」
/// - dismiss level N 代表：
///   - 關掉 N 這一層
///   - 並且把 N 以上（更上層）的 modal 一起清掉
///
/// 這個設計的目的：
/// - 在 SwiftUI 裡，如果你有多層 sheet / bottomSheet / alert overlay，
///   很容易讓每個 View 充滿 @State / @Binding 來控制呈現。
/// - Coordinator 把「呈現 / 關閉」集中管理，View 只需要表達「我要開什麼」。
class Coordinator: ObservableObject {

    /// 全域 singleton（Demo/Side project 常用）
    /// 若要更乾淨，可改成透過 DI 注入
    static let shared = Coordinator()

    /// 以 stack 形式保存所有「目前正在呈現中的 modal route」
    ///
    /// - routeStack[0] = Level 0（最底層 modal）
    /// - routeStack[1] = Level 1
    /// - routeStack[2] = Level 2 ...
    ///
    /// `@Published` 讓 UI（CoordinatorViewModifier）能跟著 routeStack 變化去更新 sheet/overlay
    @Published private var routeStack: [Route] = []

    // MARK: - Present (Write)

    /// 推入一個新的 route（modal）
    ///
    /// - Parameters:
    ///   - type: 要呈現的 modal 類型（sheet / bottomSheet / alert overlay）
    ///   - content: 建立 modal 內容的 builder
    ///     - 會提供 `Binding<Bool>` 給內容 View
    ///     - 內容 View 可以透過 `isPresented.wrappedValue = false` 來關掉自己這一層
    ///   - onDismiss: 當該 route 被 dismiss 時要做的 callback（例如清理狀態）
    ///
    /// ✅ 為什麼用 DispatchQueue.main.async？
    /// - 確保 routeStack 的 mutation 會在 main thread，避免 SwiftUI 在更新 UI 時產生 warning/競態
    func present(
        type: RouteType = .sheet,
        @ViewBuilder content: @escaping (Binding<Bool>) -> some View,
        onDismiss: (() -> Void)? = nil
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.routeStack.append(
                Route(type: type, content: content, onDismiss: onDismiss)
            )
        }
    }

    // MARK: - Query (Read)

    /// 取得指定層級（level）的 route
    /// - level 以 routeStack index 代表
    func route(at level: Int) -> Route? {
        guard level >= 0, level < routeStack.count else { return nil }
        return routeStack[level]
    }

    /// 判斷某個層級是否為 sheet
    func hasSheet(at level: Int) -> Bool {
        level < routeStack.count && routeStack[level].type == .sheet
    }

    /// 判斷某個層級是否為 bottomSheet
    func hasBottomSheet(at level: Int) -> Bool {
        level < routeStack.count && routeStack[level].type == .bottomSheet
    }

    /// 判斷某個層級是否為 alert overlay
    func hasAlert(at level: Int) -> Bool {
        level < routeStack.count && routeStack[level].type == .alert
    }

    // MARK: - Dismiss rule (Stack pop)

    /// 當某一層 modal 被關閉時呼叫（由 CoordinatorViewModifier 觸發）
    ///
    /// ✅ stack 規則：
    /// - dismiss level N → remove level N...top
    ///
    /// ✅ onDismiss callback：
    /// - 會對被移除的 routes 逐一呼叫 onDismiss
    /// - 呼叫順序採用 reversed：先通知最上層（最晚呈現的）再到下層
    func onRouteDismissed(at level: Int) {
        guard level < routeStack.count else { return }

        // 逐一通知 N...top 的 routes（從最上層開始）
        for route in routeStack[level...].reversed() {
            DispatchQueue.main.async {
                route.onDismiss?()
            }
        }

        // 真正移除 N...top
        routeStack.removeSubrange(level...)
    }
}

// MARK: - Route model

extension Coordinator {

    /// Route：代表「一層 modal」
    ///
    /// - type：modal 類型
    /// - contentBuilder：把內容 View 封裝成 AnyView（型別擦除）
    /// - onDismiss：當這層被 dismiss 的 callback
    ///
    /// ✅ 為什麼要 AnyView？
    /// - 因為我們要把不同型別的 View 存到同一個 array 裡（routeStack）
    /// - SwiftUI View 是泛型，若不 type erase 就無法放進同一個容器
    struct Route {

        let type: RouteType

        /// 用 builder 延後建立內容，並且把 View type erase 成 AnyView
        let contentBuilder: (Binding<Bool>) -> AnyView

        /// 該 route 被 dismiss 時要執行的 callback
        let onDismiss: (() -> Void)?

        init(
            type: RouteType,
            @ViewBuilder content: @escaping (Binding<Bool>) -> some View,
            onDismiss: (() -> Void)? = nil
        ) {
            self.type = type
            self.onDismiss = onDismiss
            self.contentBuilder = { isPresented in
                AnyView(content(isPresented))
            }
        }

        /// 取得內容 View
        func content(isPresented: Binding<Bool>) -> AnyView {
            contentBuilder(isPresented)
        }
    }

    /// RouteType：Coordinator 支援的 modal 類型
    ///
    /// - sheet：系統 sheet
    /// - bottomSheet：自訂 detent 高度的 bottom sheet
    /// - alert：透明背景 overlay（通常會用 transparent fullScreenCover）
    enum RouteType {
        case sheet
        case bottomSheet
        case alert
    }
}
