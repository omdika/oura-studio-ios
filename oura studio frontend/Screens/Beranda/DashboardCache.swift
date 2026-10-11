import Foundation

/// v3.70: Cache-first dashboard — tampil instan dari UserDefaults lalu revalidasi background.
enum DashboardCache {
    private static let dataKey = "oura.dashboardCache.v1.data"
    private static let dateKey = "oura.dashboardCache.v1.date"

    static func load() -> (DashboardSummary, Date)? {
        guard let data = UserDefaults.standard.data(forKey: dataKey),
              let dash = try? JSONDecoder().decode(DashboardSummary.self, from: data)
        else { return nil }
        let date = UserDefaults.standard.object(forKey: dateKey) as? Date ?? Date()
        return (dash, date)
    }

    static func save(_ dashboard: DashboardSummary, at date: Date = Date()) {
        if let data = try? JSONEncoder().encode(dashboard) {
            UserDefaults.standard.set(data, forKey: dataKey)
            UserDefaults.standard.set(date, forKey: dateKey)
        }
    }

    static func ageLabel(since date: Date?, isRefreshing: Bool = false) -> String? {
        guard let date else { return nil }
        if isRefreshing { return "memperbarui…" }
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "baru saja" }
        if mins < 60 { return "diperbarui \(mins) mnt lalu" }
        let hours = mins / 60
        return "diperbarui \(hours) jam lalu"
    }
}
