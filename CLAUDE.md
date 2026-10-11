## Project Structure

- FridgeChef/:真正写代码的地方
  - FridgeChefApp.swift:App 的入口(ModelContainer 的 Schema 为 FoodItem)
  - RootView.swift:主界面根视图(原 ContentView,后续改为 fridge / cook / settings 的 TabView)
  - Localizable.xcstrings:String Catalog(双语:en / zh-Hans)
  - Models/:数据模型
    - FoodItem.swift:@Model,食材(枚举以 raw 字符串存储,含 daysLeft)
    - FoodCategory.swift:分类枚举(meat、semiPrepared、vegetable、eggDairy)
    - StorageLocation.swift:存放位置枚举(fridge、freezer)
    - QuantityUnit.swift:单位枚举(piece、head、item、box、bunch、bag)
    - ExpiryStatus.swift:过期状态枚举(expired / today / tomorrow / soon / ok / frozen / unknown),由存放位置和 daysLeft 推导
    - ShelfLifePreset.swift:预设保质期表(先按名字查,再按分类默认值;冷冻返回 nil)
  - Assets.xcassets/:资源目录(图片、颜色、图标)

- FridgeChefTests/:单元测试

- docs/:设计文档(design-spec.md、MVP.md、plans/)和 Excalidraw 架构图(architecture.excalidraw)

- FridgeChef.xcodeproj/:Xcode 项目配置
  - project.pbxproj: 项目的核心配置
  - project.xcworkspace/: 工作区描述
  - xcuserdata/: 个人的xcode配置

## Conventions

- 最低系统版本 iOS 17.0;UI 用 SwiftUI,持久化用 SwiftData
- 枚举的 displayName 返回 LocalizedStringResource,用于中英双语
- 枚举在 FoodItem 里存 raw 字符串(categoryRaw 等),因为 #Predicate 按枚举筛选不稳定
- 每次修改完成后,必须及时更新本文件(Project Structure / Conventions),并同步更新 docs/architecture.excalidraw 架构图,保持三者与代码一致
