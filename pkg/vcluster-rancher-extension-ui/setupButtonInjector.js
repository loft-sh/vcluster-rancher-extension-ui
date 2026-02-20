const vclusterLogoWhite = require('./assets/vclusterLogoWhite.svg');

export function setupButtonInjector() {
  const addVClusterButton = () => {
    const button = document.querySelector(
      '.home-page [data-testid="cluster-create-button"]',
    );

    const existingVClusterButton = document.querySelector(
      '[data-testid="vcluster-create-button"]',
    );

    if (button && !existingVClusterButton) {
      const copiedButton = button.cloneNode(true);

      if (copiedButton) {
        copiedButton.classList.add("btn", "btn-sm", "role-primary", "vcluster-create-btn", "vcluster-create-btn--home");
        copiedButton.setAttribute("data-testid", "vcluster-create-button");
        const base = window.location.pathname.startsWith("/dashboard") ? "/dashboard" : "";
        copiedButton.setAttribute("href", `${base}/vCluster/c/_/dashboard`);
        copiedButton.innerHTML = `<img src="${vclusterLogoWhite}" alt="" class="vcluster-btn-icon">Create vCluster`;

        copiedButton.addEventListener("click", (e) => {
          e.preventDefault();
          const base = window.location.pathname.startsWith("/dashboard") ? "/dashboard" : "";
          window.location.href = `${base}/vCluster/c/_/dashboard`;
        });

        const parent = button.parentElement;
        if (parent) {
          parent.appendChild(copiedButton);
        }
      }
    }
  };

  const isButtonAdded = addVClusterButton();

  if (isButtonAdded) {
    return;
  }

  const targetNode = document.querySelector(".home-page") || document.body;
  const observer = new MutationObserver((mutations) => {
    // Only check if we need to add the button when relevant changes occur
    for (const mutation of mutations) {
      if (mutation.type === "childList" && mutation.addedNodes.length > 0) {
        addVClusterButton();
        break;
      }
    }
  });

  // More specific configuration
  observer.observe(targetNode, {
    childList: true,
    subtree: true,
  });

  return () => {
    observer.disconnect();
  };
}
