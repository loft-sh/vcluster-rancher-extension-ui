export const getCookie = (name: string) => {
  const value = `; ${document.cookie}`;
  const parts = value.split(`; ${name}=`);
  if (parts.length === 2) {
    return parts.pop()?.split(";").shift() || "";
  }
  return "";
};

function normalizeUrl(url: string): string {
  // If the URL doesn’t start with http or https, assume https.
  if (!/^https?:\/\//i.test(url)) {
    url = "https://" + url;
  }
  try {
    const parsed = new URL(url);
    // Force the protocol to be https (ignores http vs https differences)
    parsed.protocol = "https:";

    // Remove default ports if present.
    if (parsed.port === "80" || parsed.port === "443") {
      parsed.port = "";
    }

    // Remove a trailing slash from the pathname (unless it is just "/")
    let pathname = parsed.pathname;
    if (pathname !== "/" && pathname.endsWith("/")) {
      pathname = pathname.slice(0, -1);
    }
    parsed.pathname = pathname;

    // Return a string with the hostname, pathname, and search parameters (ignore protocol and hash)
    return `${parsed.hostname}${parsed.pathname}${parsed.search}`;
  } catch (e) {
    // If URL parsing fails, fallback to lowercasing and trimming.
    return url.trim().toLowerCase();
  }
}

export function areUrlsEquivalent(url1: string, url2: string): boolean {
  return normalizeUrl(url1) === normalizeUrl(url2);
}
