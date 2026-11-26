document.addEventListener("DOMContentLoaded", function () {
    const listContainer = document.getElementById("unmatchedListContainer");
    const activeBtn = document.getElementById("activeBtn");
    const inactiveBtn = document.getElementById("inactiveBtn");

    let currentRequest = null;

    function removeStatusParams() {
        const url = new URL(window.location.href);
        const paramsToRemove = ["deleted", "added", "emailUpdated", "recovered"];
        let urlWasModified = false;
        paramsToRemove.forEach((param) => {
            if (url.searchParams.has(param)) {
                url.searchParams.delete(param);
                urlWasModified = true;
            }
        });
        if (urlWasModified) {
            window.history.replaceState({}, "", url.toString());
        }
    }

    removeStatusParams();

    function updateActionForms(tab) {
        const selectedTab = normalizeTab(tab);

        document
            .querySelectorAll(".js-current-tab")
            .forEach(function (input) {
                input.value = selectedTab;
            });
    }

    function normalizeTab(tab) {
        return tab === "Deleted" ? "Deleted" : "Active";
    }

    function getCurrentTab() {
        const result = document.getElementById("unmatchedResultContent");

        if (result && result.dataset.tab) {
            return normalizeTab(result.dataset.tab);
        }

        const params = new URLSearchParams(window.location.search);
        return normalizeTab(params.get("tab"));
    }

    function updateTabButtons(tab, isLoading = false) {
        const selectedTab = normalizeTab(tab);

        if (activeBtn) {
            activeBtn.classList.toggle("active", selectedTab === "Active");
            activeBtn.disabled = isLoading;
            activeBtn.setAttribute(
                "aria-selected",
                selectedTab === "Active" ? "true" : "false"
            );
        }

        if (inactiveBtn) {
            inactiveBtn.classList.toggle("active", selectedTab === "Deleted");
            inactiveBtn.disabled = isLoading;
            inactiveBtn.setAttribute(
                "aria-selected",
                selectedTab === "Deleted" ? "true" : "false"
            );
        }
    }

    function setLoading(isLoading, tab) {
        if (listContainer) {
            listContainer.classList.toggle("opacity-50", isLoading);
            listContainer.setAttribute(
                "aria-busy",
                isLoading ? "true" : "false"
            );
        }

        updateTabButtons(tab, isLoading);
    }

    async function loadUnmatched(tab, page = 1, updateHistory = true) {
        if (!listContainer) {
            return;
        }

        const selectedTab = normalizeTab(tab);
        const selectedPage = Math.max(parseInt(page, 10) || 1, 1);
        const browserUrl = new URL(window.location.href);
        const batch = browserUrl.searchParams.get("batch") || "0";
        const ajaxUrl = new URL("unmatchedAjax.cfm", window.location.href);

        ajaxUrl.searchParams.set("batch", batch);
        ajaxUrl.searchParams.set("tab", selectedTab);
        ajaxUrl.searchParams.set("page", selectedPage.toString());

        if (currentRequest) {
            currentRequest.abort();
        }

        const controller = new AbortController();
        currentRequest = controller;
        setLoading(true, selectedTab);

        try {
            const response = await fetch(ajaxUrl.toString(), {
                method: "GET",
                headers: {
                    "X-Requested-With": "XMLHttpRequest"
                },
                signal: controller.signal,
                cache: "no-store"
            });

            if (!response.ok) {
                throw new Error("HTTP error " + response.status);
            }

            const html = await response.text();
            listContainer.innerHTML = html;

            const returnedResult = document.getElementById(
                "unmatchedResultContent"
            );
            const returnedPage = returnedResult
                ? parseInt(returnedResult.dataset.page, 10) || selectedPage
                : selectedPage;
            
            updateActionForms(selectedTab);
            updateTabButtons(selectedTab);

            if (updateHistory) {
                browserUrl.searchParams.set("tab", selectedTab);
                browserUrl.searchParams.set("page", returnedPage.toString());
                window.history.pushState(
                    { tab: selectedTab, page: returnedPage },
                    "",
                    browserUrl.toString()
                );
            }
        } catch (error) {
            if (error.name === "AbortError") {
                return;
            }

            console.error("Unable to load unmatched clients:", error);
            listContainer.innerHTML = `
                <div class="alert alert-danger" role="alert">
                    <i class="fas fa-exclamation-circle"></i>
                    Unable to load the client list. Please try again.
                </div>
            `;
        } finally {
            if (currentRequest === controller) {
                currentRequest = null;
                setLoading(false, selectedTab);
            }
        }

        updateActionForms();
    }

    if (activeBtn) {
        activeBtn.addEventListener("click", function () {
            if (getCurrentTab() !== "Active") {
                loadUnmatched("Active", 1);
            }
        });
    }

    if (inactiveBtn) {
        inactiveBtn.addEventListener("click", function () {
            if (getCurrentTab() !== "Deleted") {
                loadUnmatched("Deleted", 1);
            }
        });
    }

    if (listContainer) {
        listContainer.addEventListener("click", function (event) {
            const pageButton = event.target.closest(".js-unmatched-page");

            if (!pageButton || pageButton.disabled) {
                return;
            }

            loadUnmatched(getCurrentTab(), pageButton.dataset.page || "1");
        });
    }

    window.addEventListener("popstate", function () {
        const params = new URLSearchParams(window.location.search);
        loadUnmatched(
            normalizeTab(params.get("tab")),
            params.get("page") || "1",
            false
        );
    });

    updateTabButtons(getCurrentTab());

    const editModal = document.getElementById("editModal");
    const oldEmailInput = document.getElementById("oldEmail");
    const newEmailInput = document.getElementById("editEmail");

    if (editModal && oldEmailInput && newEmailInput) {
        editModal.addEventListener("show.bs.modal", function (event) {
            const button = event.relatedTarget;
            const email = button ? button.getAttribute("data-email") || "" : "";
            oldEmailInput.value = email;
            newEmailInput.value = email;
        });

        editModal.addEventListener("shown.bs.modal", function () {
            newEmailInput.focus();
        });

        editModal.addEventListener("hidden.bs.modal", function () {
            oldEmailInput.value = "";
            newEmailInput.value = "";
        });
    }

    const deleteModal = document.getElementById("deleteModal");
    const deleteEmailInput = document.getElementById("email");
    const emailDeleteText = document.getElementById("emailDelete");

    if (deleteModal && deleteEmailInput && emailDeleteText) {
        deleteModal.addEventListener("show.bs.modal", function (event) {
            const button = event.relatedTarget;
            const email = button ? button.getAttribute("data-email") || "" : "";
            deleteEmailInput.value = email;
            emailDeleteText.textContent = email;
        });
    }

    const forceModal = document.getElementById("forceAddModal");
    const forceEmailInput = document.getElementById("emailForce");
    const clientDirectorateText = document.getElementById("clientDirectorate");

    if (forceModal && forceEmailInput && clientDirectorateText) {
        forceModal.addEventListener("show.bs.modal", function (event) {
            const button = event.relatedTarget;
            const email = button ? button.getAttribute("data-email") || "" : "";
            forceEmailInput.value = email;
            clientDirectorateText.textContent = email;
        });
    }

    const recoveryModal = document.getElementById("recoveryModal");
    const recoveryEmailInput = document.getElementById("emailRecoveryInput");
    const recoveryEmailText = document.getElementById("emailRecovery");

    if (recoveryModal && recoveryEmailInput && recoveryEmailText) {
        recoveryModal.addEventListener("show.bs.modal", function (event) {
            const button = event.relatedTarget;
            const email = button ? button.getAttribute("data-email") || "" : "";
            recoveryEmailInput.value = email;
            recoveryEmailText.textContent = email;
        });
    }
});