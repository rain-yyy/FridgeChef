//
//  RootView.swift
//  FridgeChef
//

import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case fridge, cook, settings
}

/// App 根视图:冰箱 / 做饭 / 设置三个标签页
struct RootView: View {
    @State private var selection: AppTab = Self.initialTab // 默认选中fridge标签
    @State private var toast: Toast? // 底部提示(比如扣减完成后),几秒后自动消失

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                FridgeView() // 冰箱页自带顶部「+」按钮和标题
            }
            .tabItem { tabLabel("tab.fridge", icon: .iconFridge, selectedIcon: .tabFridgeSelected, tab: .fridge) }
            .tag(AppTab.fridge)

            CookView(selectedTab: $selection) // 做饭页自带 NavigationStack(推荐结果要 push)
            .tabItem { tabLabel("tab.cook", icon: .iconCook, selectedIcon: .tabCookSelected, tab: .cook) }
            .tag(AppTab.cook)

            NavigationStack {
                SettingsView()
            }
            .tabItem { tabLabel("tab.settings", icon: .iconSettings, selectedIcon: .tabSettingsSelected, tab: .settings) }
            .tag(AppTab.settings)
        }
        .tint(Color.ink) // 设置标签颜色
        .overlay(alignment: .bottom) {
            if let toast {
                ToastView(message: toast.message)
                    .padding(.bottom, 96) // 浮在 Tab 栏上方
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(1.8))
                        withAnimation { self.toast = nil }
                    }
            }
        }
        .environment(\.showToast) { message in
            withAnimation(.spring(duration: 0.3)) { toast = Toast(message: message) }
        }
    }

    private struct Toast: Equatable {
        let id = UUID()
        let message: String
    }

    // 创建标签样式，选中使用selectedIcon，没选中使用icon
    private func tabLabel(_ title: LocalizedStringKey, icon: ImageResource, selectedIcon: ImageResource, tab: AppTab) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(selection == tab ? selectedIcon : icon)
        }
    }

    // 启动时选中的标签;DEBUG 下可用启动参数 -debugTab cook|settings 指定(方便截图)
    private static var initialTab: AppTab {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "debugTab") {
        case "cook": return .cook
        case "settings": return .settings
        default: break
        }
        #endif
        return .fridge
    }
}

#Preview {
    let container = PreviewData.container()
    return RootView()
        .modelContainer(container)
        .environment(AISettings())
        .environment(PreviewData.menuStore(for: container))
}
