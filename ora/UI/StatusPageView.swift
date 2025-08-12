import SwiftUI

// MARK: - StatusPageView

struct StatusPageView: View {
    let error: Error
    let failedURL: URL?
    let onRetry: () -> Void
    let onGoBack: (() -> Void)?
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Error icon
            Image(systemName: errorIcon)
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundColor(theme.foreground.opacity(0.4))

            VStack(spacing: 12) {
                // Error title
                Text(errorTitle)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(theme.foreground)
                    .multilineTextAlignment(.center)

                // Error description
                Text(errorDescription)
                    .font(.system(size: 14))
                    .foregroundColor(theme.foreground.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Failed URL (if available)
                if let url = failedURL {
                    Text(url.absoluteString)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(theme.foreground.opacity(0.5))
                        .padding(.top, 8)
                }
            }

            // Action buttons
            HStack(spacing: 16) {
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if let goBack = onGoBack {
                    Button("Go Back") {
                        goBack()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    private var errorIcon: String {
        switch errorType {
        case .network:
            return "wifi.slash"
        case .notFound:
            return "questionmark.circle"
        case .security:
            return "lock.slash"
        case .timeout:
            return "clock.badge.exclamationmark"
        case .unknown:
            return "exclamationmark.triangle"
        }
    }

    private var errorTitle: String {
        switch errorType {
        case .network:
            return "Can't Connect to the Internet"
        case .notFound:
            return "Page Not Found"
        case .security:
            return "Connection Not Secure"
        case .timeout:
            return "Request Timed Out"
        case .unknown:
            return "Something Went Wrong"
        }
    }

    private var errorDescription: String {
        switch errorType {
        case .network:
            return "Check your internet connection and try again."
        case .notFound:
            return "The page you're looking for doesn't exist or has been moved."
        case .security:
            return "The connection to this site is not secure."
        case .timeout:
            return "The page took too long to load. Try again or check your connection."
        case .unknown:
            return "An unexpected error occurred while loading this page."
        }
    }

    private var errorType: ErrorType {
        let nsError = error as NSError

        // Network-related errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotConnectToHost:
                return .network
            case NSURLErrorCannotFindHost,
                 NSURLErrorBadURL:
                return .notFound
            case NSURLErrorServerCertificateUntrusted,
                 NSURLErrorClientCertificateRequired,
                 NSURLErrorSecureConnectionFailed:
                return .security
            case NSURLErrorTimedOut:
                return .timeout
            default:
                return .unknown
            }
        }

        // WebKit errors
        if nsError.domain == "WebKitErrorDomain" {
            return .notFound
        }

        return .unknown
    }

    private enum ErrorType {
        case network
        case notFound
        case security
        case timeout
        case unknown
    }
}
