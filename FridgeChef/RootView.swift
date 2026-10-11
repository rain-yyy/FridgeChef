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
    @State private var selection: AppTab = .fridge // 默认选中fridge标签

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { // 
                StyleGallery()
                    .toolbar {
                        Button {
                            // 添加食材的逻辑
                        } label: { Image(.iconAdd).resizable().frame(width: 22, height: 22) } // 将图片固定为22x22
                    }
            }
            .tabItem { tabLabel("tab.fridge", icon: .iconFridge, selectedIcon: .tabFridgeSelected, tab: .fridge) }
            .tag(AppTab.fridge)

            NavigationStack {
                placeholder(title: "cook.title", icon: .iconCook)
            }
            .tabItem { tabLabel("tab.cook", icon: .iconCook, selectedIcon: .tabCookSelected, tab: .cook) }
            .tag(AppTab.cook)

            NavigationStack {
                placeholder(title: "settings.title", icon: .iconSettings)
            }
            .tabItem { tabLabel("tab.settings", icon: .iconSettings, selectedIcon: .tabSettingsSelected, tab: .settings) }
            .tag(AppTab.settings)
        }
        .tint(Color.ink) // 设置标签颜色
    }

    // 创建标签样式，选中使用selectedIcon，没选中使用icon
    private func tabLabel(_ title: LocalizedStringKey, icon: ImageResource, selectedIcon: ImageResource, tab: AppTab) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(selection == tab ? selectedIcon : icon)
        }
    }

    // 创建占位符视图
    private func placeholder(title: LocalizedStringKey, icon: ImageResource) -> some View {
        ScrollView {
            PageHeader(title: title, icon: icon).padding(16)
        }
        .pageBackground()
    }
}

#Preview {
    RootView()
        .modelContainer(for: FoodItem.self, inMemory: true)
}
