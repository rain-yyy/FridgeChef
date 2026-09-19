import SwiftUI

// T0.1 scaffold only: proves the app can reach Supabase (local by default).
// Replaced by the real View → ViewModel → Repository stack starting T0.6/T0.8.
struct ContentView: View {
    @State private var status = "未检查"

    var body: some View {
        VStack(spacing: 16) {
            Text("FridgeChef").font(.largeTitle)
            Text("Supabase 健康检查").font(.headline)
            Text(status).multilineTextAlignment(.center).padding(.horizontal)
            Button("重新检查") { Task { await checkHealth() } }
        }
        .padding()
        .task { await checkHealth() }
    }

    private func checkHealth() async {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: urlString)?.appendingPathComponent("rest/v1/")
        else {
            status = "缺少 SUPABASE_URL/SUPABASE_ANON_KEY（见 Debug.xcconfig.example）"
            return
        }

        var request = URLRequest(url: url)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                status = "无效响应"
                return
            }
            status = (200..<300).contains(http.statusCode)
                ? "已连接 Supabase（HTTP \(http.statusCode)）"
                : "响应异常（HTTP \(http.statusCode)）"
        } catch {
            status = "连接失败：\(error.localizedDescription)\n（本地开发请先运行 supabase start）"
        }
    }
}

#Preview {
    ContentView()
}
