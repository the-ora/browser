import Foundation
@preconcurrency import WebKit

// swiftlint:disable type_body_length function_body_length
struct FingerprintingProtectionProfile: Equatable {
    let hardwareConcurrency: Int
    let deviceMemory: Int
    let maxTouchPoints: Int
    let webdriver: Bool
    let platform: String
    let vendor: String
    let language: String
    let languages: [String]
    let screenWidth: Int
    let screenHeight: Int
    let availWidth: Int
    let availHeight: Int
    let colorDepth: Int
    let pixelDepth: Int
    let devicePixelRatio: Double
    let webGLVendor: String
    let webGLRenderer: String
    let webGLRendererName: String
    let webGLVersion: String
    let webGLShadingLanguageVersion: String
    let canvasShift: Int
    let audioNoise: Double
    let audioBucketSize: Int
    let mediaDeviceKinds: [String]

    static let balanced = FingerprintingProtectionProfile(
        hardwareConcurrency: 8,
        deviceMemory: 8,
        maxTouchPoints: 0,
        webdriver: false,
        platform: "MacIntel",
        vendor: "Apple Computer, Inc.",
        language: "en-US",
        languages: ["en-US", "en"],
        screenWidth: 1440,
        screenHeight: 900,
        availWidth: 1440,
        availHeight: 877,
        colorDepth: 24,
        pixelDepth: 24,
        devicePixelRatio: 2,
        webGLVendor: "Apple Inc.",
        webGLRenderer: "Apple GPU",
        webGLRendererName: "WebKit WebGL",
        webGLVersion: "WebGL 1.0",
        webGLShadingLanguageVersion: "WebGL GLSL ES 1.0",
        canvasShift: 1,
        audioNoise: 0.000_015_258_789_062_5,
        audioBucketSize: 64,
        mediaDeviceKinds: ["audioinput", "audiooutput", "videoinput"]
    )

    func scriptSource() -> String {
        let profileObject: [String: Any] = [
            "audioBucketSize": audioBucketSize,
            "audioNoise": audioNoise,
            "availHeight": availHeight,
            "availWidth": availWidth,
            "canvasShift": canvasShift,
            "colorDepth": colorDepth,
            "deviceMemory": deviceMemory,
            "devicePixelRatio": devicePixelRatio,
            "hardwareConcurrency": hardwareConcurrency,
            "language": language,
            "languages": languages,
            "maxTouchPoints": maxTouchPoints,
            "mediaDeviceKinds": mediaDeviceKinds,
            "pixelDepth": pixelDepth,
            "platform": platform,
            "screenHeight": screenHeight,
            "screenWidth": screenWidth,
            "vendor": vendor,
            "webdriver": webdriver,
            "webGLRenderer": webGLRenderer,
            "webGLRendererName": webGLRendererName,
            "webGLShadingLanguageVersion": webGLShadingLanguageVersion,
            "webGLVendor": webGLVendor,
            "webGLVersion": webGLVersion
        ]

        guard JSONSerialization.isValidJSONObject(profileObject),
              let data = try? JSONSerialization.data(withJSONObject: profileObject, options: [.sortedKeys]),
              let profileJSON = String(data: data, encoding: .utf8)
        else {
            return ""
        }

        return """
        (function () {
            if (window.__oraFingerprintingProtectionInstalled) {
                return;
            }
            window.__oraFingerprintingProtectionInstalled = true;

            const profile = \(profileJSON);

            function defineGetter(target, property, getter) {
                if (!target) return;
                try {
                    Object.defineProperty(target, property, {
                        configurable: true,
                        enumerable: false,
                        get: getter
                    });
                } catch (error) {}
            }

            function defineValue(target, property, value) {
                defineGetter(target, property, function () { return value; });
            }

            function wrapMethod(target, property, wrapper) {
                if (!target || typeof target[property] !== 'function') return;
                const original = target[property];
                try {
                    Object.defineProperty(target, property, {
                        configurable: true,
                        value: wrapper(original)
                    });
                } catch (error) {}
            }

            function cloneLanguages() {
                return profile.languages.slice();
            }

            function makeDevice(kind, index) {
                const suffix = String(index + 1);
                const device = {
                    deviceId: 'ora-' + kind + '-' + suffix,
                    groupId: 'ora-group-' + kind,
                    kind: kind,
                    label: '',
                    toJSON: function () {
                        return {
                            deviceId: this.deviceId,
                            groupId: this.groupId,
                            kind: this.kind,
                            label: this.label
                        };
                    }
                };

                return Object.freeze(device);
            }

            function normalizeMediaDevices(devices) {
                const hasLabels = Array.isArray(devices) && devices.some(function (device) {
                    return !!(device && device.label);
                });
                if (hasLabels) {
                    return devices;
                }

                return profile.mediaDeviceKinds.map(function (kind, index) {
                    return makeDevice(kind, index);
                });
            }

            function shouldSanitizeCanvas(canvas) {
                if (!canvas) return false;
                const width = canvas.width || 0;
                const height = canvas.height || 0;
                const area = width * height;
                return width > 0 && height > 0 && area <= 262144;
            }

            function mutatePixelData(data, step) {
                if (!data || !data.length) return;
                const stride = Math.max(8, step * 16);
                for (let index = 0; index < data.length; index += stride) {
                    data[index] = (data[index] + profile.canvasShift) & 255;
                    if (index + 1 < data.length) {
                        data[index + 1] = (data[index + 1] + profile.canvasShift) & 255;
                    }
                }
            }

            function cloneAndSanitizeCanvas(canvas) {
                if (!shouldSanitizeCanvas(canvas)) return canvas;

                try {
                    const clone = document.createElement('canvas');
                    clone.width = canvas.width;
                    clone.height = canvas.height;
                    const context = clone.getContext('2d');
                    if (!context) return canvas;

                    context.drawImage(canvas, 0, 0);
                    const imageData = context.getImageData(0, 0, clone.width, clone.height);
                    mutatePixelData(imageData.data, Math.max(1, clone.width % 13));
                    context.putImageData(imageData, 0, 0);
                    return clone;
                } catch (error) {
                    return canvas;
                }
            }

            function sanitizeImageData(imageData, widthHint) {
                if (!imageData || !imageData.data) return imageData;
                mutatePixelData(imageData.data, Math.max(1, widthHint % 11));
                return imageData;
            }

            function sanitizeAudioBuffer(buffer) {
                if (!buffer || typeof buffer.numberOfChannels !== 'number') return buffer;

                for (let channel = 0; channel < buffer.numberOfChannels; channel += 1) {
                    let samples;
                    try {
                        samples = buffer.getChannelData(channel);
                    } catch (error) {
                        continue;
                    }

                    const stride = Math.max(profile.audioBucketSize, 32);
                    for (let index = 0; index < samples.length; index += stride) {
                        const sample = samples[index] || 0;
                        samples[index] = Math.fround(sample + profile.audioNoise);
                    }
                }

                return buffer;
            }

            function sanitizeArrayValues(values, mode) {
                if (!values || typeof values.length !== 'number') return values;
                const stride = Math.max(profile.audioBucketSize, 16);
                for (let index = 0; index < values.length; index += stride) {
                    if (mode === 'float') {
                        values[index] = Math.fround((values[index] || 0) + profile.audioNoise);
                    } else {
                        values[index] = Math.max(0, Math.min(255, (values[index] || 0) + 1));
                    }
                }
                return values;
            }

            defineValue(Navigator.prototype, 'hardwareConcurrency', profile.hardwareConcurrency);
            defineValue(Navigator.prototype, 'deviceMemory', profile.deviceMemory);
            defineValue(Navigator.prototype, 'maxTouchPoints', profile.maxTouchPoints);
            defineValue(Navigator.prototype, 'webdriver', profile.webdriver);
            defineValue(Navigator.prototype, 'platform', profile.platform);
            defineValue(Navigator.prototype, 'vendor', profile.vendor);
            defineValue(Navigator.prototype, 'language', profile.language);
            defineGetter(Navigator.prototype, 'languages', cloneLanguages);

            defineValue(Screen.prototype, 'width', profile.screenWidth);
            defineValue(Screen.prototype, 'height', profile.screenHeight);
            defineValue(Screen.prototype, 'availWidth', profile.availWidth);
            defineValue(Screen.prototype, 'availHeight', profile.availHeight);
            defineValue(Screen.prototype, 'colorDepth', profile.colorDepth);
            defineValue(Screen.prototype, 'pixelDepth', profile.pixelDepth);
            defineValue(window, 'devicePixelRatio', profile.devicePixelRatio);

            if (navigator.permissions && typeof navigator.permissions.query === 'function') {
                const originalQuery = navigator.permissions.query.bind(navigator.permissions);
                navigator.permissions.query = function (parameters) {
                    const permissionName = parameters && parameters.name;
                    if (permissionName === 'camera' ||
                        permissionName === 'microphone' ||
                        permissionName === 'geolocation' ||
                        permissionName === 'notifications') {
                        return Promise.resolve({ state: 'prompt', onchange: null });
                    }
                    return originalQuery(parameters);
                };
            }

            if (navigator.mediaDevices && typeof navigator.mediaDevices.enumerateDevices === 'function') {
                const originalEnumerateDevices = navigator.mediaDevices.enumerateDevices.bind(navigator.mediaDevices);
                navigator.mediaDevices.enumerateDevices = function () {
                    return originalEnumerateDevices().then(normalizeMediaDevices);
                };
            }

            wrapMethod(HTMLCanvasElement.prototype, 'toDataURL', function (original) {
                return function () {
                    const sanitizedCanvas = cloneAndSanitizeCanvas(this);
                    return original.apply(sanitizedCanvas, arguments);
                };
            });

            wrapMethod(HTMLCanvasElement.prototype, 'toBlob', function (original) {
                return function () {
                    const sanitizedCanvas = cloneAndSanitizeCanvas(this);
                    return original.apply(sanitizedCanvas, arguments);
                };
            });

            wrapMethod(CanvasRenderingContext2D && CanvasRenderingContext2D.prototype, 'getImageData', function (original) {
                return function () {
                    const result = original.apply(this, arguments);
                    if (!this || !this.canvas || !shouldSanitizeCanvas(this.canvas)) {
                        return result;
                    }
                    return sanitizeImageData(result, this.canvas.width || 1);
                };
            });

            function wrapWebGLContext(contextType) {
                if (!contextType || !contextType.prototype) return;

                wrapMethod(contextType.prototype, 'getParameter', function (original) {
                    return function (parameter) {
                        if (parameter === 37445) return profile.webGLVendor;
                        if (parameter === 37446) return profile.webGLRenderer;
                        if (parameter === 7936) return profile.webGLVendor;
                        if (parameter === 7937) return profile.webGLRendererName;
                        if (parameter === 7938) return profile.webGLVersion;
                        if (parameter === 35724) return profile.webGLShadingLanguageVersion;
                        return original.apply(this, arguments);
                    };
                });
            }

            wrapWebGLContext(window.WebGLRenderingContext);
            wrapWebGLContext(window.WebGL2RenderingContext);

            if (window.OfflineAudioContext && window.OfflineAudioContext.prototype) {
                wrapMethod(window.OfflineAudioContext.prototype, 'startRendering', function (original) {
                    return function () {
                        const rendering = original.apply(this, arguments);
                        return Promise.resolve(rendering).then(function (buffer) {
                            return sanitizeAudioBuffer(buffer);
                        });
                    };
                });
            }

            wrapMethod(window.AnalyserNode && window.AnalyserNode.prototype, 'getFloatFrequencyData', function (original) {
                return function (array) {
                    const response = original.apply(this, arguments);
                    sanitizeArrayValues(array, 'float');
                    return response;
                };
            });

            wrapMethod(window.AnalyserNode && window.AnalyserNode.prototype, 'getFloatTimeDomainData', function (original) {
                return function (array) {
                    const response = original.apply(this, arguments);
                    sanitizeArrayValues(array, 'float');
                    return response;
                };
            });

            wrapMethod(window.AnalyserNode && window.AnalyserNode.prototype, 'getByteFrequencyData', function (original) {
                return function (array) {
                    const response = original.apply(this, arguments);
                    sanitizeArrayValues(array, 'byte');
                    return response;
                };
            });

            wrapMethod(window.AnalyserNode && window.AnalyserNode.prototype, 'getByteTimeDomainData', function (original) {
                return function (array) {
                    const response = original.apply(this, arguments);
                    sanitizeArrayValues(array, 'byte');
                    return response;
                };
            });
        })();
        """
    }
}

// swiftlint:enable type_body_length function_body_length

final class BrowserPrivacyService {
    private enum StaticRuleListIdentifier: String {
        case trackers = "com.orabrowser.privacy.trackers.v1"
        case thirdPartyCookies = "com.orabrowser.privacy.cookies.third-party.v1"
        case allCookies = "com.orabrowser.privacy.cookies.all.v1"
    }

    static let shared = BrowserPrivacyService()

    private let ruleListStore = WKContentRuleListStore.default()!
    private let cacheLock = NSLock()
    private let artifactStore = ContentBlockerArtifactStore.shared
    private var cachedRuleLists: [String: WKContentRuleList] = [:]
    private var pendingRuleListCallbacks: [String: [(WKContentRuleList?) -> Void]] = [:]

    func activeRuleListIdentifiers(for spaceID: UUID) -> [String] {
        let privacySettings = SettingsStore.shared.privacySettings(for: spaceID)
        guard privacySettings.adBlock.enabled else { return [] }

        return SettingsStore.shared.adBlockFilterLists
            .filter { privacySettings.adBlock.enabledListIDs.contains($0.id) }
            .flatMap { record -> [String] in
                guard let revision = record.activeRevision else { return [] }
                return artifactStore.ruleListIdentifiers(for: record.id, revision: revision)
            }
    }

    func prepareConfiguration(
        _ configuration: WKWebViewConfiguration,
        spaceID: UUID,
        completion: @escaping () -> Void
    ) {
        let privacySettings = SettingsStore.shared.privacySettings(for: spaceID)
        let enabledRuleLists = enabledRuleLists(for: spaceID, privacySettings: privacySettings)
        let group = DispatchGroup()

        for identifier in enabledRuleLists {
            group.enter()
            contentRuleList(for: identifier) { ruleList in
                DispatchQueue.main.async {
                    if let ruleList {
                        configuration.userContentController.add(ruleList)
                    }
                    group.leave()
                }
            }
        }

        group.enter()
        applyCookiePolicy(privacySettings.cookiesPolicy, to: configuration.websiteDataStore) {
            group.leave()
        }

        group.notify(queue: .main, execute: completion)
    }

    static func privacyScripts(for privacySettings: SpacePrivacySettings) -> [BrowserUserScript] {
        guard privacySettings.blockFingerprinting else { return [] }

        return [
            BrowserUserScript(
                name: "ora-fingerprinting-protection",
                source: fingerprintingProtectionScriptSource(),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        ]
    }

    static func fingerprintingProtectionScriptSource() -> String {
        FingerprintingProtectionProfile.balanced.scriptSource()
    }

    private func enabledRuleLists(for spaceID: UUID, privacySettings: SpacePrivacySettings) -> [String] {
        var identifiers: [String] = []

        if privacySettings.blockThirdPartyTrackers {
            identifiers.append(StaticRuleListIdentifier.trackers.rawValue)
        }

        switch privacySettings.cookiesPolicy {
        case .allowAll:
            break
        case .blockThirdParty:
            identifiers.append(StaticRuleListIdentifier.thirdPartyCookies.rawValue)
        case .blockAll:
            identifiers.append(StaticRuleListIdentifier.allCookies.rawValue)
        }

        return identifiers + activeRuleListIdentifiers(for: spaceID)
    }

    private func applyCookiePolicy(
        _ policy: CookiesPolicy,
        to dataStore: WKWebsiteDataStore,
        completion: @escaping () -> Void
    ) {
        guard #available(macOS 14.0, *) else {
            completion()
            return
        }

        let cookiePolicy: WKHTTPCookieStore.CookiePolicy = switch policy {
        case .blockAll:
            .disallow
        case .allowAll, .blockThirdParty:
            .allow
        }

        dataStore.httpCookieStore.setCookiePolicy(cookiePolicy, completionHandler: completion)
    }

    private func contentRuleList(
        for identifier: String,
        completion: @escaping (WKContentRuleList?) -> Void
    ) {
        cacheLock.lock()
        if let cachedRuleList = cachedRuleLists[identifier] {
            cacheLock.unlock()
            completion(cachedRuleList)
            return
        }

        if pendingRuleListCallbacks[identifier] != nil {
            pendingRuleListCallbacks[identifier, default: []].append(completion)
            cacheLock.unlock()
            return
        }

        pendingRuleListCallbacks[identifier] = [completion]
        cacheLock.unlock()

        ruleListStore.lookUpContentRuleList(forIdentifier: identifier) { [weak self] ruleList, _ in
            guard let self else { return }

            if let ruleList {
                self.finishLoadingRuleList(identifier, ruleList: ruleList)
                return
            }

            guard let encodedRuleList = Self.encodedRuleList(for: identifier, artifactStore: self.artifactStore) else {
                self.finishLoadingRuleList(identifier, ruleList: nil)
                return
            }

            self.ruleListStore.compileContentRuleList(
                forIdentifier: identifier,
                encodedContentRuleList: encodedRuleList
            ) { [weak self] compiledRuleList, error in
                if let error {
                    print("Failed to compile privacy rule list \(identifier): \(error.localizedDescription)")
                }
                self?.finishLoadingRuleList(identifier, ruleList: compiledRuleList)
            }
        }
    }

    private func finishLoadingRuleList(_ identifier: String, ruleList: WKContentRuleList?) {
        cacheLock.lock()
        if let ruleList {
            cachedRuleLists[identifier] = ruleList
        }
        let callbacks = pendingRuleListCallbacks.removeValue(forKey: identifier) ?? []
        cacheLock.unlock()

        callbacks.forEach { $0(ruleList) }
    }

    private static func encodedRuleList(
        for identifier: String,
        artifactStore: ContentBlockerArtifactStore
    ) -> String? {
        switch identifier {
        case StaticRuleListIdentifier.trackers.rawValue:
            return encodeRules(networkBlockingRules(for: trackerDomains))
        case StaticRuleListIdentifier.thirdPartyCookies.rawValue:
            return encodeRules([
                [
                    "trigger": [
                        "url-filter": ".*",
                        "load-type": ["third-party"]
                    ],
                    "action": ["type": "block-cookies"]
                ]
            ])
        case StaticRuleListIdentifier.allCookies.rawValue:
            return encodeRules([
                [
                    "trigger": ["url-filter": ".*"],
                    "action": ["type": "block-cookies"]
                ]
            ])
        default:
            return artifactStore.encodedRuleList(for: identifier)
        }
    }

    private static func networkBlockingRules(for domains: [String]) -> [[String: Any]] {
        domains.map { domain in
            [
                "trigger": [
                    "url-filter": regexForDomain(domain),
                    "load-type": ["third-party"]
                ],
                "action": ["type": "block"]
            ]
        }
    }

    static func regexForDomain(_ domain: String) -> String {
        let escapedDomain = NSRegularExpression.escapedPattern(for: domain)
        return "^https?://([^/]+\\.)?\(escapedDomain)(?:[/:]|$)"
    }

    private static func encodeRules(_ rules: [[String: Any]]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: rules, options: []),
              let encoded = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }

        return encoded
    }

    private static let trackerDomains = [
        "google-analytics.com",
        "googletagmanager.com",
        "doubleclick.net",
        "googleadservices.com",
        "facebook.net",
        "connect.facebook.net",
        "analytics.twitter.com",
        "ads-twitter.com",
        "snap.licdn.com",
        "px.ads.linkedin.com",
        "bat.bing.com",
        "clarity.ms",
        "cdn.segment.com",
        "api.segment.io",
        "api.amplitude.com",
        "cdn.amplitude.com",
        "mixpanel.com",
        "api.mixpanel.com",
        "fullstory.com",
        "edge.fullstory.com",
        "static.hotjar.com",
        "script.hotjar.com",
        "intercom.io",
        "widget.intercom.io",
        "static.intercomassets.com"
    ]
}
