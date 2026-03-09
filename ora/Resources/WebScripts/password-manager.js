(function () {
    if (window.__oraPasswordManagerInstalled) {
        return;
    }
    window.__oraPasswordManagerInstalled = true;

    const bridge = window.__oraBridge;
    if (!bridge || typeof bridge.postMessage !== "function") {
        return;
    }

    let activeField = null;
    let blurTimeout = null;
    let overlayKeyboardNavigationState = {
        active: false
    };

    function send(payload) {
        try {
            bridge.postMessage("passwordManager", JSON.stringify(payload));
        } catch (error) {}
    }

    function ensureFieldID(element) {
        if (!element) {
            return null;
        }
        if (!element.dataset.oraPasswordFieldId) {
            const random = window.crypto && window.crypto.randomUUID
                ? window.crypto.randomUUID()
                : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
            element.dataset.oraPasswordFieldId = `ora-password-${random}`;
        }
        return element.dataset.oraPasswordFieldId;
    }

    function isVisible(element) {
        if (!element) {
            return false;
        }
        const rect = element.getBoundingClientRect();
        const style = window.getComputedStyle(element);
        return rect.width > 0
            && rect.height > 0
            && style.display !== "none"
            && style.visibility !== "hidden";
    }

    function isRelevantInput(element) {
        if (!(element instanceof HTMLInputElement)) {
            return false;
        }
        if (element.disabled || element.readOnly || element.type === "hidden") {
            return false;
        }
        return ["text", "email", "password", "tel", "url", "search"].includes(element.type);
    }

    function isUsernameField(element) {
        if (!isRelevantInput(element)) {
            return false;
        }
        if (element.type === "password") {
            return false;
        }

        const joined = [
            element.name,
            element.id,
            element.placeholder,
            element.autocomplete,
            element.getAttribute("aria-label")
        ]
            .filter(Boolean)
            .join(" ")
            .toLowerCase();

        return element.type === "email"
            || joined.includes("email")
            || joined.includes("user")
            || joined.includes("login")
            || joined.includes("identifier")
            || element.autocomplete === "username";
    }

    function fieldKindFor(element) {
        if (!(element instanceof HTMLInputElement)) {
            return null;
        }

        if (element.type === "password") {
            return "password";
        }

        if (element.type === "email" || element.autocomplete === "email") {
            return "email";
        }

        if (isUsernameField(element)) {
            return "username";
        }

        return null;
    }

    function isNewPasswordField(element) {
        const joined = [
            element.name,
            element.id,
            element.placeholder,
            element.autocomplete,
            element.getAttribute("aria-label")
        ]
            .filter(Boolean)
            .join(" ")
            .toLowerCase();

        return element.autocomplete === "new-password"
            || joined.includes("confirm")
            || joined.includes("repeat")
            || joined.includes("new password")
            || joined.includes("create password");
    }

    function relevantFieldsFor(element) {
        const scope = element.form || element.closest("form") || document;
        const inputs = Array.from(scope.querySelectorAll("input"))
            .filter(isRelevantInput)
            .filter(isVisible);
        const passwordFields = inputs.filter((input) => input.type === "password");

        if (!passwordFields.length) {
            return null;
        }

        const firstPasswordIndex = inputs.findIndex((input) => input.type === "password");
        const usernameField = inputs
            .slice(0, firstPasswordIndex === -1 ? inputs.length : firstPasswordIndex)
            .reverse()
            .find(isUsernameField)
            || inputs.find(isUsernameField);

        const createAccount = passwordFields.length > 1 || passwordFields.some(isNewPasswordField);

        return {
            action: createAccount ? "createAccount" : "login",
            usernameField: usernameField || null,
            passwordFields
        };
    }

    function rectPayload(element) {
        const rect = element.getBoundingClientRect();
        return {
            x: rect.x,
            y: rect.y,
            width: rect.width,
            height: rect.height
        };
    }

    function focusPayload(element) {
        const group = relevantFieldsFor(element);
        if (!group) {
            return null;
        }

        const fieldKind = fieldKindFor(element);
        if (!fieldKind) {
            return null;
        }

        return {
            fieldID: ensureFieldID(element),
            hostname: window.location.hostname,
            action: group.action,
            fieldKind,
            usernameFieldID: ensureFieldID(group.usernameField),
            passwordFieldIDs: group.passwordFields.map(ensureFieldID).filter(Boolean),
            rect: rectPayload(element)
        };
    }

    function scheduleRectUpdate() {
        if (!activeField || !isVisible(activeField)) {
            return;
        }

        send({
            type: "rect",
            fieldID: ensureFieldID(activeField),
            rect: rectPayload(activeField)
        });
    }

    function emitFocus(element) {
        const payload = focusPayload(element);
        if (!payload) {
            activeField = null;
            return;
        }

        if (blurTimeout) {
            clearTimeout(blurTimeout);
            blurTimeout = null;
        }

        activeField = element;
        send({
            type: "focus",
            focus: payload
        });
    }

    function handleFocus(event) {
        const target = event.target;
        if (!(target instanceof HTMLInputElement)) {
            return;
        }
        emitFocus(target);
    }

    function handleBlur(event) {
        const target = event.target;
        if (!(target instanceof HTMLInputElement)) {
            return;
        }

        blurTimeout = window.setTimeout(() => {
            if (document.activeElement !== target) {
                activeField = null;
                send({
                    type: "blur",
                    fieldID: ensureFieldID(target)
                });
            }
        }, 50);
    }

    function handleSubmit(event) {
        const form = event.target;
        if (!(form instanceof HTMLFormElement)) {
            return;
        }

        const inputs = Array.from(form.querySelectorAll("input"))
            .filter(isRelevantInput)
            .filter(isVisible);
        const passwordFields = inputs.filter((input) => input.type === "password" && input.value);

        if (!passwordFields.length) {
            return;
        }

        const usernameField = inputs.find((input) => isUsernameField(input) && input.value);
        const createAccount = passwordFields.length > 1 || passwordFields.some(isNewPasswordField);
        const chosenPassword = passwordFields[passwordFields.length - 1].value;

        send({
            type: "submit",
            submit: {
                hostname: window.location.hostname,
                username: usernameField ? usernameField.value : "",
                password: chosenPassword,
                action: createAccount ? "createAccount" : "login"
            }
        });
    }

    function sendKeyCommand(command) {
        send({
            type: "keyCommand",
            keyCommand: command
        });
    }

    function handleKeyDown(event) {
        if (!overlayKeyboardNavigationState.active || !activeField || event.target !== activeField) {
            return;
        }

        switch (event.key) {
        case "ArrowDown":
            event.preventDefault();
            event.stopPropagation();
            sendKeyCommand("moveDown");
            break;
        case "ArrowUp":
            event.preventDefault();
            event.stopPropagation();
            sendKeyCommand("moveUp");
            break;
        case "Enter":
            event.preventDefault();
            event.stopPropagation();
            sendKeyCommand("activate");
            break;
        case "Escape":
            event.preventDefault();
            event.stopPropagation();
            sendKeyCommand("dismiss");
            break;
        default:
            break;
        }
    }

    function fillField(element, value, highlightColor) {
        if (!element || typeof value !== "string") {
            return;
        }

        const originalBackground = element.style.backgroundColor;
        element.focus();

        const prototype = element instanceof HTMLTextAreaElement
            ? HTMLTextAreaElement.prototype
            : HTMLInputElement.prototype;
        const descriptor = Object.getOwnPropertyDescriptor(prototype, "value");

        if (descriptor && typeof descriptor.set === "function") {
            descriptor.set.call(element, value);
        } else {
            element.value = value;
        }

        const isPassword = element.type === "password";
        element.dispatchEvent(new InputEvent("input", {
            bubbles: true,
            composed: true,
            data: isPassword ? null : value,
            inputType: "insertReplacementText"
        }));
        element.dispatchEvent(new Event("change", { bubbles: true, composed: true }));
        element.style.backgroundColor = highlightColor;
        window.setTimeout(() => {
            element.style.backgroundColor = originalBackground;
        }, 1200);
    }

    function fieldByID(fieldID) {
        if (!fieldID) {
            return null;
        }

        if (window.CSS && typeof window.CSS.escape === "function") {
            return document.querySelector(`[data-ora-password-field-id="${window.CSS.escape(fieldID)}"]`);
        }

        return Array.from(document.querySelectorAll("[data-ora-password-field-id]"))
            .find((element) => element.dataset.oraPasswordFieldId === fieldID) || null;
    }

    function submitFilledForm(request) {
        const submitSource = fieldByID(request.usernameFieldID)
            || (request.passwordFieldIDs || []).map(fieldByID).find(Boolean);
        const form = submitSource && submitSource.form;

        if (!form) {
            return;
        }

        window.setTimeout(() => {
            if (typeof form.requestSubmit === "function") {
                form.requestSubmit();
                return;
            }

            const submitControl = form.querySelector("button[type=\"submit\"], input[type=\"submit\"]");
            if (submitControl && typeof submitControl.click === "function") {
                submitControl.click();
                return;
            }

            form.submit();
        }, 0);
    }

    window.__oraPasswordManager = {
        fillCredentials(payload) {
            const request = typeof payload === "string" ? JSON.parse(payload) : payload;
            const highlightColor = request.highlightColor || "#E8F5E9";

            if (request.usernameFieldID && typeof request.username === "string") {
                fillField(fieldByID(request.usernameFieldID), request.username, highlightColor);
            }

            (request.passwordFieldIDs || []).forEach((fieldID) => {
                fillField(fieldByID(fieldID), request.password, highlightColor);
            });

            if (request.submitAfterFill) {
                submitFilledForm(request);
            }
        },
        setOverlayKeyboardActive(payload) {
            overlayKeyboardNavigationState.active = typeof payload === "string"
                ? JSON.parse(payload)
                : Boolean(payload);
        }
    };

    document.addEventListener("focusin", handleFocus, true);
    document.addEventListener("focusout", handleBlur, true);
    document.addEventListener("keydown", handleKeyDown, true);
    document.addEventListener("submit", handleSubmit, true);
    window.addEventListener("scroll", scheduleRectUpdate, true);
    window.addEventListener("resize", scheduleRectUpdate, true);
})();
