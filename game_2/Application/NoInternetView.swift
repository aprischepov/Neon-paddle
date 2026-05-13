import Combine
import SwiftUI
import UIKit

// MARK: - Shared types (UIKit host + SwiftUI)

enum NoInternetPresentationReason {
    case firstLaunchConfigPending
    case recurringWebViewOffline
}

@MainActor
protocol NoInternetScreenHost: AnyObject {
    func noInternetScreenDidAppear()
    func noInternetRetryTapped()
    func noInternetRoutingReadyNotification()
    func noInternetConnectivityChanged()
}

@MainActor
final class NoInternetScreenModel: ObservableObject {
    let reason: NoInternetPresentationReason
    weak var host: NoInternetScreenHost?
    @Published private(set) var isOnline: Bool

    init(reason: NoInternetPresentationReason) {
        self.reason = reason
        isOnline = ConnectivityMonitor.shared.isOnline
    }

    func refreshOnlineFlag() {
        isOnline = ConnectivityMonitor.shared.isOnline
    }
}


// MARK: - Pieces (обычная декомпозиция SwiftUI)

private struct NoInternetBackgroundView: View {
    let isLandscape: Bool

    var body: some View {
        Image(isLandscape ? .connectBGHorizontal : .connectBGVertical)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()
    }
}

private struct NoInternetConnectPlaqueView: View {
    let isLandscape: Bool

    var body: some View {
        ZStack {
            if isLandscape {
                Image(.connect)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.vertical, 90)
                    .padding(.leading, 46)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Image(.connect)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, 90)
                    .padding(.top, 12)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

// MARK: - Screen (корневой SwiftUI-view)

struct NoInternetView: View {
    @ObservedObject var model: NoInternetScreenModel

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            ZStack {
                NoInternetBackgroundView(isLandscape: isLandscape)
                NoInternetConnectPlaqueView(isLandscape: isLandscape)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            model.refreshOnlineFlag()
            model.host?.noInternetScreenDidAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: .connectivityDidChange)) { _ in
            model.refreshOnlineFlag()
            model.host?.noInternetConnectivityChanged()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appStartupRoutingReady)) { _ in
            model.host?.noInternetRoutingReadyNotification()
        }
    }
}

#if DEBUG
#Preview("No Internet") {
    NoInternetView(model: NoInternetScreenModel(reason: .firstLaunchConfigPending))
}
#endif
