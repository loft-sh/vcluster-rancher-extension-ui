export function setupButtonInjector() {
  const addVClusterButton = () => {
    const button = document.querySelector(
      '.home-page [data-testid="cluster-create-button"]',
    );

    const existingVClusterButton = document.querySelector(
      '[data-testid="vcluster-create-button"]',
    );

    if (existingVClusterButton) {
      return true;
    }

    if (button && !existingVClusterButton) {
      const copiedButton = button.cloneNode(true);

      if (copiedButton) {
        copiedButton.classList.add("btn", "btn-sm", "role-primary");
        copiedButton.setAttribute("data-testid", "vcluster-create-button");
        copiedButton.setAttribute("href", "/vCluster/c/_/dashboard");
        copiedButton.setAttribute(
          "style",
          "margin-left: 10px;background-color: rgb(255, 102, 0)",
        );
        copiedButton.textContent = "Create vCluster";

        copiedButton.addEventListener("click", (e) => {
          e.preventDefault();
          window.location.href = "/vCluster/c/_/dashboard";
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
