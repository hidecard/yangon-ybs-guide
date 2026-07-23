import ActivityKit
import SwiftUI
import WidgetKit

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable {
    var routeName: String
    var stopName: String
    var distanceKm: Double
    var etaMinutes: Int
    var updatedAt: Int
  }

  var id = UUID()
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    return "\(id)_\(key)"
  }
}

let sharedDefault = UserDefaults(suiteName: "group.net.arkaryan.ybs_guide")!

struct YbsLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      ZStack {
        RoundedRectangle(cornerRadius: 16)
          .fill(Color(.systemGray6))
        VStack(alignment: .leading, spacing: 6) {
          Text(context.state.routeName)
            .font(.caption2)
            .foregroundColor(Color(.label))
            .lineLimit(1)
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(context.state.stopName)
              .font(.body.bold())
              .foregroundColor(Color(.label))
              .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(String(format: "%.1f", context.state.distanceKm)) km")
              .font(.caption)
              .foregroundColor(Color(.secondaryLabel))
            if context.state.etaMinutes > 0 {
              Text("~\(context.state.etaMinutes) min")
                .font(.caption)
                .foregroundColor(Color(.systemBlue))
            }
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
      }
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label {
            Text(context.state.routeName)
              .font(.caption2)
          } icon: {
            Image(systemName: "bus.fill")
              .foregroundColor(Color(.systemBlue))
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 2) {
            Text("\(String(format: "%.1f", context.state.distanceKm)) km")
              .font(.caption.bold())
            if context.state.etaMinutes > 0 {
              Text("~\(context.state.etaMinutes) min")
                .font(.caption2)
                .foregroundColor(Color(.secondaryLabel))
            }
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(context.state.stopName)
            .font(.caption.bold())
            .lineLimit(1)
        }
      } compactLeading: {
        Text(context.state.routeName)
          .font(.caption2)
          .lineLimit(1)
      } compactTrailing: {
        Text("\(String(format: "%.1f", context.state.distanceKm)) km")
          .font(.caption2)
      } minimal: {
        VStack(spacing: 0) {
          Image(systemName: "bus.fill")
            .font(.caption2)
          Text("\(context.state.etaMinutes)")
            .font(.system(size: 10, weight: .bold))
        }
      }
    }
  }
}

@main
struct YbsLiveActivityWidgets: WidgetBundle {
  var body: some Widget {
    YbsLiveActivityWidget()
  }
}
