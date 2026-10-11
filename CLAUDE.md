## Project Structure

- FridgeChef/:真正写代码的地方
  - FridgeChefApp.swift:App 的入口(ModelContainer 的 Schema 为 FoodItem;DEBUG 下启动参数 -useSampleData 改用内存中的示例数据)
  - RootView.swift:根视图,TabView(冰箱 / 做饭 / 设置);AppTab 枚举;Tab 选中态用 TabIcons 里填了蜂蜜黄的图标
  - Localizable.xcstrings:String Catalog(双语:en / zh-Hans)
  - Models/:数据模型
    - FoodItem.swift:@Model,食材(枚举以 raw 字符串存储,含 daysLeft)
    - FoodCategory.swift:分类枚举(meat、semiPrepared、vegetable、eggDairy)
    - StorageLocation.swift:存放位置枚举(fridge、freezer)
    - QuantityUnit.swift:单位枚举(piece、head、item、box、bunch、bag)
    - ExpiryStatus.swift:过期状态枚举(expired / today / tomorrow / soon / ok / frozen / unknown),由存放位置和 daysLeft 推导
    - ShelfLifePreset.swift:预设保质期表(先按名字查,再按分类默认值;冷冻返回 nil)
  - Theme/:视觉基础
    - AppFont.swift:启动时注册站酷快乐体;Font.handwritten(size, relativeTo:) 只用于标题和按钮
    - Styles.swift:Metrics(圆角 / 描边尺寸)、.cardStyle()、.pageBackground()、PrimaryButtonStyle(.primary,蜂蜜黄 + 3pt 硬投影)、SecondaryButtonStyle(.secondary)
  - Views/Components/:通用组件
    - PageHeader.swift:Tab 根页面的大标题(快乐体 34 + 图标 + 说明);.handwrittenInlineTitle() 用于 push 页面
    - CategoryBadge.swift:分类圆形徽章;FoodCategory 的 tint / icon
    - ExpiryTag.swift:过期标签胶囊;ExpiryStatus 的 tint / icon
  - Views/Fridge/:冰箱 Tab(库存管理)
    - FridgeView.swift:冰箱页(顶部「+」、标题、搜索、冷藏/冷冻筛选、分组列表、左滑删除、空状态);DEBUG 启动参数 -debugOpenEditor add|<食材名> 直接打开编辑页,方便截图
    - FridgeSections.swift:StorageFilter + 分组逻辑(「尽快用掉」= 冷藏且 ≤2 天含已过期;其余按分类;组内按剩余天数,冷冻排最后)
    - FoodItemCard.swift:食材卡片;FoodItem.quantityText / detailText
    - FridgeEmptyView.swift:冰箱空状态
    - ItemEditorSheet.swift:添加 / 编辑 Sheet(Form;保存并继续添加;删除带确认)
    - ItemDraft.swift:编辑页草稿和过期日规则(自动计算 / 手动修改 / 恢复默认 / 冷冻隐藏 / 编辑模式冷冻改冷藏从今天重算)
  - Views/PreviewData.swift:DEBUG 示例数据(和设计稿一致),供 #Preview 和 -useSampleData 使用
  - Resources/Fonts/:ZCOOLKuaiLe-Regular.ttf + OFL.txt(字体许可)
  - Assets.xcassets/:资源目录
    - Colors/:全部颜色(每个都有浅色 / 深色两套值),代码里用 Color.cream / .paper / .ink / .cocoa / .honey / .onPastel 等
    - Icons/:单色线稿图标(template 渲染,用 foregroundStyle 上色),ImageResource 名为 .iconXxx
    - TabIcons/:Tab 选中态图标(original 渲染,带深色版本)
    - Illustrations/:插画(空冰箱、生成中、网络出错、AI 出错、钥匙;original 渲染,带深色版本)

- FridgeChefTests/:单元测试(Swift Testing,测试 struct 标 @MainActor)
  - FridgeChefTests.swift:ExpiryStatus、ShelfLifePreset
  - FridgeTests.swift:FridgeSections 分组 / 筛选 / 搜索,ItemDraft 过期日规则

- scripts/gen_assets.py:从 Design/ 设计稿生成 Colors / Icons / TabIcons / Illustrations 和 AccentColor(改颜色就改脚本里的 COLORS 再运行 python3 scripts/gen_assets.py,不要手改生成的 Contents.json)

- docs/:设计文档(design-spec.md、MVP.md、plans/)和 Excalidraw 架构图(architecture.excalidraw)

- FridgeChef.xcodeproj/:Xcode 项目配置
  - project.pbxproj: 项目的核心配置
  - project.xcworkspace/: 工作区描述
  - xcuserdata/: 个人的xcode配置

## Conventions

- 最低系统版本 iOS 17.0;UI 用 SwiftUI,持久化用 SwiftData
- 枚举的 displayName 返回 LocalizedStringResource,用于中英双语
- 枚举在 FoodItem 里存 raw 字符串(categoryRaw 等),因为 #Predicate 按枚举筛选不稳定
- 颜色和图标一律用 Asset 自动生成的符号(Color.ink、Image(.iconAdd)),不写死十六进制;画在粉彩 / 蜂蜜黄底上的文字和图标用 .onPastel
- 不用 UINavigationBar.appearance():在 iOS 26 上它会让 SwiftUI 的大标题消失;根页面标题用 PageHeader,push 页面用 .handwrittenInlineTitle()
- 每次修改完成后,必须及时更新本文件(Project Structure / Conventions),并同步更新 docs/architecture.excalidraw 架构图,保持三者与代码一致
- 每次修改完成后,必须及时更新 .gitignore
