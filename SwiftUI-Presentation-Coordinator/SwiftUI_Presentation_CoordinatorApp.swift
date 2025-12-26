//
//  SwiftUI_Presentation_CoordinatorApp.swift
//  SwiftUI-Presentation-Coordinator
//
//  Created by 許佳豪 on 2025/12/26.
//

import SwiftUI

@main
struct SwiftUI_Presentation_CoordinatorApp: App {
    var body: some Scene {
        WindowGroup {
            DemoHomeView()
                .modifier(CoordinatorViewModifier())
        }
    }
}
