(function () {
  const repo = "yatima1460/Drill";
  const aurUrl = "https://aur.archlinux.org/packages/drill-search";
  const actionsRoot = document.getElementById("release-actions");
  const releaseDateNode = document.getElementById("release-date");
  if (!actionsRoot) return;

  const detectCurrentOs = () => {
    const platform = String(navigator.platform || "").toLowerCase();
    const ua = String(navigator.userAgent || "").toLowerCase();
    if (/android|iphone|ipad|ipod/.test(ua) || (platform === "macintel" && navigator.maxTouchPoints > 1)) return "";
    if (platform.includes("win") || ua.includes("windows")) return "windows";
    if (platform.includes("mac") || ua.includes("mac os")) return "macos";
    if (platform.includes("linux") || ua.includes("linux")) return "linux";
    return "";
  };
  const currentOs = detectCurrentOs();

  // The release workflow publishes these installers. Other assets stay on the release page.
  const packages = new Map([
    ["Drill-windows-x86_64.zip", ["windows", "Windows x64", "windows-logo.svg"]],
    ["Drill-macos-arm64.dmg", ["macos", "macOS · Apple silicon", "apple-logo.svg"]],
    ["Drill-macos-x86_64.dmg", ["macos", "macOS · Intel", "apple-logo.svg"]],
    ["Drill-linux-amd64.deb", ["linux", "Linux .deb", "debian-logo.svg"]],
    ["Drill-linux-x86_64.AppImage", ["linux", "Linux AppImage x64", "appimage-logo.svg"]],
    ["Drill-linux-x86_64.pkg.tar.zst", ["linux", "Arch Linux pkg", "arch-linux-logo.svg"]],
  ]);

  function createButton(label, href, icon, osType) {
    const link = document.createElement("a");
    link.className = "btn btn-primary";
    link.href = href;
    link.target = "_blank";
    link.rel = "noopener noreferrer";
    if (icon) {
      link.classList.add("btn-with-icon");
      const image = document.createElement("img");
      image.className = "os-icon-img";
      image.src = icon;
      image.alt = "";
      link.append(image);
    }
    link.append(document.createTextNode(label));
    if (currentOs && currentOs === osType) link.classList.add("btn-current-os");
    return link;
  }

  const formatRelativeAge = (fromDate, toDate) => {
    const ms = Math.max(0, toDate.getTime() - fromDate.getTime());
    const dayMs = 24 * 60 * 60 * 1000;
    const days = Math.floor(ms / dayMs);
    if (days < 1) {
      const hourMs = 60 * 60 * 1000;
      if (ms < hourMs) return "less than an hour ago";
      const hours = Math.floor(ms / hourMs);
      return hours === 1 ? "1 hour ago" : hours + " hours ago";
    }
    if (days < 30) return days === 1 ? "1 day ago" : days + " days ago";
    if (days < 365) {
      const months = Math.floor(days / 30);
      return months === 1 ? "1 month ago" : months + " months ago";
    }
    const years = Math.floor(days / 365);
    return years === 1 ? "1 year ago" : years + " years ago";
  };

  const createOsSection = (title) => {
    const section = document.createElement("section");
    section.className = "download-group";
    const heading = document.createElement("h2");
    heading.className = "download-group-title";
    heading.textContent = title;
    const actions = document.createElement("div");
    actions.className = "download-group-actions";
    section.appendChild(heading);
    section.appendChild(actions);
    return { section, actions };
  };

  function renderRelease(release) {
    const date = new Date(release.published_at || release.created_at || "");
    const title = release.name || release.tag_name;
    if (title && Number.isFinite(date.getTime())) {
      const latest = document.createElement("a");
      latest.href = "https://github.com/" + repo + "/releases/latest";
      latest.textContent = String(title);
      const time = document.createElement("time");
      time.dateTime = date.toISOString();
      time.textContent = date.toLocaleDateString(undefined, {
        year: "numeric", month: "short", day: "numeric",
      });
      releaseDateNode.replaceChildren("Latest release: ", latest, " · ", time,
        " (" + formatRelativeAge(date, new Date()) + ")");
    }

    const sections = {
      windows: createOsSection("Windows"),
      linux: createOsSection("Linux"),
      macos: createOsSection("macOS"),
    };
    const assets = Array.isArray(release.assets) ? release.assets : [];
    let downloads = 0;
    const tag = release.tag_name;
    if (typeof tag !== "string" || !tag || tag === "." || tag === "..") return;
    for (const asset of assets) {
      if (!asset || typeof asset.name !== "string") continue;
      const info = packages.get(asset.name);
      if (!info) continue;
      const [os, label, icon] = info;
      const href = "https://github.com/" + repo + "/releases/download/" +
        encodeURIComponent(tag) + "/" + encodeURIComponent(asset.name);
      sections[os].actions.append(createButton(label, href, icon, os));
      downloads++;
    }
    if (!downloads) return;
    sections.linux.actions.append(createButton("AUR (legacy Python)", aurUrl, "arch-linux-logo.svg", "linux"));
    const order = ["windows", "linux", "macos"];
    if (order.includes(currentOs)) {
      order.splice(order.indexOf(currentOs), 1);
      order.unshift(currentOs);
    }
    const groups = [];
    for (const os of order) {
      const group = sections[os];
      if (!group.actions.childElementCount) continue;
      if (currentOs && os !== currentOs) group.section.classList.add("download-group-secondary");
      groups.push(group.section);
    }
    actionsRoot.replaceChildren(...groups);
  }

  fetch("https://api.github.com/repos/" + repo + "/releases/latest", { credentials: "omit" })
    .then((response) => {
      if (!response.ok) throw new Error("Release details unavailable");
      return response.json();
    })
    .then(renderRelease)
    .catch(() => {
      // The static release and feed links also work without GitHub API access.
    });
})();
