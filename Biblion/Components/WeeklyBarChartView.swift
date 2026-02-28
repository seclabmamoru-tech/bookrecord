import SwiftUI
import Charts

/// 週次実行率を表示する棒グラフコンポーネント
struct WeeklyBarChartView: View {

    /// [(ラベル, 値)] 形式のデータ
    let data: [(String, Double)]
    var barColor: Color = .indigo

    var body: some View {
        Chart {
            ForEach(data, id: \.0) { item in
                BarMark(
                    x: .value("Label", item.0),
                    y: .value("Value", item.1)
                )
                .foregroundStyle(barColor)
                .cornerRadius(4)
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { value in
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)%").font(.caption2)
                    }
                }
                AxisGridLine()
            }
        }
    }
}

#Preview {
    WeeklyBarChartView(data: [
        ("4/1", 80.0),
        ("4/8", 60.0),
        ("4/15", 100.0),
        ("4/22", 40.0)
    ])
    .frame(height: 160)
    .padding()
}
