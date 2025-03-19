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
        copiedButton.classList.add("btn", "btn-sm", "role-primary");
        copiedButton.setAttribute("data-testid", "vcluster-create-button");
        copiedButton.setAttribute("href", "/vCluster/c/_/dashboard");
        copiedButton.setAttribute("style", "margin-left: 10px;");
        copiedButton.textContent = "Create vCluster";

        copiedButton.addEventListener("click", (e) => {
          e.preventDefault();
          window.location.href = "/vCluster/c/_/dashboard";
        });

        const vclusterLogo = document.createElement("img");
        vclusterLogo.src = require("./assets/vclusterLogo.svg");
        vclusterLogo.setAttribute("style", "margin-right: 5px;");
        vclusterLogo.setAttribute("width", "20");
        vclusterLogo.setAttribute("height", "20");

        copiedButton.insertBefore(vclusterLogo, copiedButton.firstChild);

        const parent = button.parentElement;
        if (parent) {
          parent.appendChild(copiedButton);
        }
      }
    }
  };

  addVClusterButton();

  const observer = new MutationObserver((mutations) => {
    addVClusterButton();
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
  });

  setInterval(addVClusterButton, 2000);

  if (window.hasOwnProperty("$nuxt") && window.$nuxt && window.$nuxt.$router) {
    window.$nuxt.$router.afterEach(() => {
      setTimeout(addVClusterButton, 500);
    });
  }
}
