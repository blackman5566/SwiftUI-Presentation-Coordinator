//
//  BottomSheetModifier.swift
//  SwiftUI_Wallet
//
//  Created by 許佳豪 on 2025/12/19.
//

import SwiftUI

// MARK: - BottomSheetModifier (Item-based)

/// BottomSheetModifier（Item 版本）
///
/// ✅ 目的：
/// SwiftUI 的 `.sheet` 預設高度通常不是「依內容自適應」，而是由系統決定。
/// 這個 Modifier 會「量出 sheet 內容 View 的實際高度」，並把它設定成 detent height，
/// 達成「內容多高，sheet 就多高」的效果。
///
/// ✅ 使用情境：
/// - 你想用 `.sheet(item:)`（有 item 才顯示、item 為 nil 就關）
/// - 並希望 sheet 高度會跟內容變動（例如：展開更多區塊、顯示錯誤訊息）
///
/// ✅ 核心做法：
/// 1) 用 `GeometryReader` 讀取內容高度
/// 2) 透過 `PreferenceKey` 往外傳高度
/// 3) `onPreferenceChange` 收到高度後更新 `sheetHeight`
/// 4) `presentationDetents([.height(sheetHeight)])` 讓 sheet 高度跟著變
struct BottomSheetModifier<Item: Identifiable, ContentView: View>: ViewModifier {

    /// 控制 sheet 顯示/關閉的 item binding
    /// - item != nil → 會顯示 sheet
    /// - item == nil → sheet 關閉
    private let item: Binding<Item?>

    /// sheet 的內容 View builder（依 item 產生對應內容）
    private let contentView: (Item) -> ContentView

    /// 動態量測到的內容高度
    /// 初始為 0，拿到 PreferenceKey 回傳後才會更新
    @State private var sheetHeight: CGFloat = .zero

    init(item: Binding<Item?>, @ViewBuilder contentView: @escaping (Item) -> ContentView) {
        self.item = item
        self.contentView = contentView
    }

    func body(content: Content) -> some View {
        content
            .sheet(item: item) { item in
                ZStack {
                    // 這裡用灰色當背景只是 demo/占位
                    // 你也可以改成 clear 或用 Material
                    Color.gray.ignoresSafeArea()

                    contentView(item)
                        // ✅ fixedSize 的目的：
                        // 避免內容被 sheet 的 layout 壓縮，導致 GeometryReader 測到的高度不準。
                        // （尤其是 VStack 內容依 intrinsic size 撐開時，這行常常能讓高度變得可靠）
                        .fixedSize(horizontal: false, vertical: true)

                        // ✅ 用 overlay + GeometryReader 量出「內容 View」實際高度
                        // 然後透過 PreferenceKey 往外傳遞
                        .overlay {
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: InnerHeightPreferenceKey.self,
                                    value: geometry.size.height
                                )
                            }
                        }

                        // ✅ 每次高度變動（內容增減、文字換行、Dynamic Type...）
                        // 這裡都會收到新高度，更新 sheetHeight
                        .onPreferenceChange(InnerHeightPreferenceKey.self) { newHeight in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                sheetHeight = newHeight
                            }
                        }
                }

                // ✅ 讓 sheet 的 detent 只有一個：內容高度
                // 注意：高度為 0 時可能會出現不自然的跳動
                // 若你遇到閃動，可加上 min height，例如 max(newHeight, 100)
                .presentationDetents([.height(sheetHeight)])
            }
    }
}

// MARK: - BooleanBottomSheetModifier (Bool-based)

/// BooleanBottomSheetModifier（Bool 版本）
///
/// ✅ 跟上面的 Item 版本做一樣的事，只是控制方式改成：
/// - isPresented = true → 顯示 sheet
/// - isPresented = false → 關閉 sheet
///
/// 適合情境：
/// - 不需要帶 item 資料，只想顯示/關閉
/// - 或你原本就是 `.sheet(isPresented:)` 的寫法
struct BooleanBottomSheetModifier<ContentView: View>: ViewModifier {
    private let isPresented: Binding<Bool>
    private let contentView: () -> ContentView

    @State private var sheetHeight: CGFloat = .zero

    init(isPresented: Binding<Bool>, @ViewBuilder contentView: @escaping () -> ContentView) {
        self.isPresented = isPresented
        self.contentView = contentView
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: isPresented) {
                ZStack {
                    Color.gray.ignoresSafeArea()

                    contentView()
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay {
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: InnerHeightPreferenceKey.self,
                                    value: geometry.size.height
                                )
                            }
                        }
                        .onPreferenceChange(InnerHeightPreferenceKey.self) { newHeight in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                sheetHeight = newHeight
                            }
                        }
                }
                .presentationDetents([.height(sheetHeight)])
            }
    }
}

// MARK: - View Extensions (public API)

extension View {

    /// 對外 API：Bool 版本
    ///
    /// 用法：
    /// ```swift
    /// @State var show = false
    /// ...
    /// .bottomSheet(isPresented: $show) {
    ///     MyBottomSheetContent()
    /// }
    /// ```
    func bottomSheet(
        isPresented: Binding<Bool>,
        @ViewBuilder contentView: @escaping () -> some View
    ) -> some View {
        modifier(BooleanBottomSheetModifier(isPresented: isPresented, contentView: contentView))
    }

    /// 對外 API：Item 版本
    ///
    /// 用法：
    /// ```swift
    /// @State var selected: MyItem?
    /// ...
    /// .bottomSheet(item: $selected) { item in
    ///     SheetDetail(item: item)
    /// }
    /// ```
    func bottomSheet<Item>(
        item: Binding<Item?>,
        @ViewBuilder contentView: @escaping (Item) -> some View
    ) -> some View where Item: Identifiable {
        modifier(BottomSheetModifier(item: item, contentView: contentView))
    }
}

// MARK: - PreferenceKey (height channel)

/// InnerHeightPreferenceKey
///
/// ✅ 這是一個「把子 View 的高度傳到父層」的通道。
/// GeometryReader 讀到高度後，透過 preference 發送；
/// 父層用 onPreferenceChange 接收。
struct InnerHeightPreferenceKey: PreferenceKey {

    /// 預設值：0（表示還沒量到）
    static let defaultValue: CGFloat = .zero

    /// reduce 的策略：用最新值覆蓋
    /// - 如果你有多個地方同時上報高度，這裡會取最後一個
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
