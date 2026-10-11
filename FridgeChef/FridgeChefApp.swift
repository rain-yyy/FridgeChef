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

    // 初始化
    init() {
        AppFont.register() // 注册自定义字体
    }

    // 初始化模型容器
    var sharedModelContainer: ModelContainer = {
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

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer) // 挂载模型容器
    }
}
