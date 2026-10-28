import Foundation

enum OraBrowserScripts {
    static func userScripts() -> [BrowserUserScript] {
        var scripts = [
            BrowserUserScript(
                name: "ora-bridge",
                source: bridgeScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ),
            BrowserUserScript(
                name: "ora-navigation",
                source: navigationAndMediaScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        ]

        if let passwordManagerScript = loadResourceScript(named: "password-manager") {
            scripts.append(
                BrowserUserScript(
                    name: "ora-password-manager",
                    source: passwordManagerScript,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                )
            )
        }

        return scripts
    }

    private static func loadResourceScript(named name: String) -> String? {
        guard let scriptURL = Bundle.main.url(forResource: name, withExtension: "js"),
              let script = try? String(contentsOf: scriptURL, encoding: .utf8)
        else {
            return nil
        }
        return script
    }

    private static let bridgeScript = """
    (function () {
        if (window.__oraBridge && typeof window.__oraBridge.postMessage === 'function') {
            return;
        }

        window.__oraBridge = {
            postMessage: function(name, payload) {
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[name]) {
                        window.webkit.messageHandlers[name].postMessage(payload);
                        return true;
                    }
                } catch (error) {}
                return false;
            }
        };
    })();
    """

    private static let navigationAndMediaScript = """
    (function () {
        let lastHref = location.href;
        let lastTitle = document.title;

        function post(name, payload) {
            try {
                window.__oraBridge && window.__oraBridge.postMessage(name, payload);
            } catch (error) {}
        }

        function notifyChange(force = false) {
            if (force || location.href !== lastHref || document.title !== lastTitle) {
                lastHref = location.href;
                lastTitle = document.title;
                post('listener', JSON.stringify({ href: lastHref, title: lastTitle }));
            }
        }

        const titleObserver = new MutationObserver(() => notifyChange());
        const titleElement = document.querySelector('title');
        if (titleElement) {
            titleObserver.observe(titleElement, { childList: true });
        }

        setInterval(() => notifyChange(), 500);
        window.addEventListener('popstate', () => notifyChange(true));
        notifyChange(true);

        function postHover(url) {
            post('linkHover', url || "");
        }

        function onMouseOver(event) {
            const anchor = event.target.closest && event.target.closest('a[href]');
            postHover(anchor ? anchor.href : '');
        }

        function onMouseOut(event) {
            const related = event.relatedTarget;
            if (!related || !event.currentTarget.contains(related)) {
                postHover("");
            }
        }

        document.addEventListener('mouseover', onMouseOver, true);
        document.addEventListener('mouseout', onMouseOut, true);
    })();

    (function () {
        if (window.__oraMediaInstalled) {
            return;
        }
        window.__oraMediaInstalled = true;

        function post(payload) {
            try {
                window.__oraBridge && window.__oraBridge.postMessage('mediaEvent', JSON.stringify(payload));
            } catch (error) {}
        }

        function findNextButton() {
            const selectors = [
                '.ytp-next-button',
                'button[aria-label*="Next" i]',
                'button[title*="Next" i]',
                '[data-testid="control-button-skip-forward"]'
            ];
            for (const selector of selectors) {
                const element = document.querySelector(selector);
                if (element) return element;
            }
            return null;
        }

        function findPrevButton() {
            const selectors = [
                '.ytp-prev-button',
                'button[aria-label*="Previous" i]',
                'button[title*="Previous" i]',
                '[data-testid="control-button-skip-backward"]'
            ];
            for (const selector of selectors) {
                const element = document.querySelector(selector);
                if (element) return element;
            }
            return null;
        }

        function caps() {
            post({
                type: 'caps',
                hasNext: !!findNextButton(),
                hasPrevious: !!findPrevButton()
            });
        }

        const stateFrom = (element) => ({
            type: 'state',
            wasPlayed: element && element.__oraWasPlayed,
            state: element && !element.paused ? 'playing' : 'paused',
            volume: element ? (element.muted ? 0 : element.volume) : undefined,
            title: document.title
        });

        function watchRemoval(element, callback) {
            const observer = new MutationObserver((mutations) => {
                for (const mutation of mutations) {
                    for (const removed of mutation.removedNodes) {
                        if (removed === element || removed.contains(element)) {
                            callback();
                            observer.disconnect();
                            return;
                        }
                    }
                }
            });

            observer.observe(document.body, { childList: true, subtree: true });
        }

        // Only media the user can hear count as "played" and bring up the mini
        // player: not muted autoplay videos (page backgrounds, previews, ads),
        // nor videos without any sound track.
        function isAudible(element) {
            return !element.muted && element.volume > 0 && hasSound(element);
        }

        // Whether the media has a sound track. Unknown until its metadata is
        // loaded, so it is checked again once it plays.
        function hasSound(element) {
            if (element.tagName === 'AUDIO') return true;
            if (element.readyState < HTMLMediaElement.HAVE_METADATA) return false;
            if (!element.audioTracks || element.audioTracks.length > 0) return true;
            // Streams (Media Source on blob: URLs, media streams) may list no
            // tracks: assume they have sound. Files list theirs reliably.
            const source = element.currentSrc || '';
            return source.startsWith('blob:') || !!element.srcObject;
        }

        // Marks playing, audible media as played; returns whether it did.
        function markPlayedIfAudible(element, update) {
            if (element.__oraWasPlayed || element.paused || !isAudible(element)) return false;
            element.__oraWasPlayed = true;
            update();
            return true;
        }

        function attach(element) {
            if (!element || element.__oraAttached) return;
            element.__oraAttached = true;
            const update = () => post(stateFrom(element));
            element.addEventListener('play', () => {
                if (!markPlayedIfAudible(element, update)) update();
            });
            // Playing: the metadata, hence the sound track, is known.
            element.addEventListener('playing', () => markPlayedIfAudible(element, update));
            element.addEventListener('pause', update);
            element.addEventListener('ended', () => post({ type: 'ended' }));
            element.addEventListener('volumechange', () => {
                // A muted video the user unmutes while it plays now counts.
                markPlayedIfAudible(element, update);
                post({ type: 'volume', volume: element.muted ? 0 : element.volume });
            });
            if (!element.paused) {
                if (!markPlayedIfAudible(element, update)) update();
            }
            watchRemoval(element, () => post({ type: 'removed' }));
        }

        function scan() {
            document.querySelectorAll('video, audio').forEach(attach);
            caps();
        }

        const observer = new MutationObserver(scan);
        observer.observe(document.documentElement, { childList: true, subtree: true });
        scan();

        window.__oraMedia = {
            active: null,
            _pick() {
                const elements = Array.from(document.querySelectorAll('video, audio'));
                const playing = elements.find((element) => !element.paused);
                this.active = playing || elements[0] || null;
                return this.active;
            },
            play() {
                try { (this._pick() || {}).play(); return true; } catch (error) { return false; }
            },
            pause() {
                try { (this._pick() || {}).pause(); return true; } catch (error) { return false; }
            },
            toggle() {
                const element = this._pick();
                if (!element) return false;
                if (element.paused) {
                    element.play();
                } else {
                    element.pause();
                }
                return true;
            },
            setVolume(value) {
                const element = this._pick();
                if (!element) return false;
                element.muted = false;
                element.volume = Math.max(0, Math.min(1, value));
                post({ type: 'volume', volume: element.volume });
                return true;
            },
            deltaVolume(delta) {
                const element = this._pick();
                if (!element) return false;
                element.muted = false;
                element.volume = Math.max(0, Math.min(1, (element.volume || 0) + delta));
                post({ type: 'volume', volume: element.volume });
                return true;
            },
            next() {
                const element = findNextButton();
                if (!element) return false;
                element.click();
                caps();
                return true;
            },
            previous() {
                const element = findPrevButton();
                if (!element) return false;
                element.click();
                caps();
                return true;
            },
            title() {
                return document.title;
            }
        };

        window.__oraTriggerPiP = function(isActive = false) {
            const video = document.querySelector('video');

            // Same rule as the mini player: only a video the user can hear
            // (not muted, and with a sound track) goes to Picture in Picture.
            if (
                video &&
                video.tagName === 'VIDEO' &&
                !document.pictureInPictureElement &&
                !video.paused &&
                !isActive &&
                isAudible(video)
            ) {
                video.requestPictureInPicture().catch(() => {});
            } else if (document.pictureInPictureElement) {
                document.exitPictureInPicture().catch(() => {});
            }
        };

        post({ type: 'ready', title: document.title });
    })();
    """
}
