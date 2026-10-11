//
//  FridgeChefApp.swift
//  FridgeChef
//
//  Created by Rainyyy-day on 10/10/2026.
//

import SwiftUI
import SwiftData

@main
struct FridgeChefApp: App {

    // AI 设置(Key 在钥匙串、模型 ID 在 UserDefaults)和菜单推荐状态,通过 environment 共享给各页面
    @State private var aiSettings = AISettings()
    @State private var menuStore = MenuStore(fileURL: Self.usesSampleData ? nil : MenuStore.defaultFileURL)

    // 初始化
    init() {
        AppFont.register() // 注册自定义字体
    }

    // 初始化模型容器
    var sharedModelContainer: ModelContainer = {
        #if DEBUG
        // 调试用:启动参数 -useSampleData 时用内存中的示例数据,不碰真实存储
        if usesSampleData {
            return PreviewData.container()
        }
        #endif

        let schema = Schema([
            FoodItem.self, // 所有需要存储的数据模型
        ]) 

        let modelConfiguration   = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // 调试用:启动参数 -useSampleData 时用内存中的示例数据(食材和推荐结果都不写入真实存储)
    private static var usesSampleData: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-useSampleData")
        #else
        false
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(aiSettings)
                .environment(menuStore)
        }
        .modelContainer(sharedModelContainer) // 挂载模型容器
    }
}
