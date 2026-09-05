"use strict";

// Temporary comparison UI, isolated so it can be removed after selection.
(() => {
  const palettes = [
    { id: "copper", name: "Copper", color: "#e8a785" },
    { id: "mint", name: "Mint", color: "#9bddc5" },
    { id: "ice", name: "Ice", color: "#98c7f4" },
    { id: "violet", name: "Violet", color: "#bfaff5" },
    { id: "silver", name: "Silver", color: "#d4d7de" },
  ];
  const storageKey = "ccpocket_lp_palette";
  const picker = document.createElement("details");
  picker.className = "palette-preview";
  picker.open = true;
  const summary = document.createElement("summary");
  summary.append("COLOR PREVIEW");
  const current = document.createElement("span");
  current.className = "palette-preview-current";
  summary.append(current);
  picker.append(summary);
  const options = document.createElement("div");
  options.className = "palette-options";
  options.setAttribute("role", "group");
  options.setAttribute("aria-label", "Color palette");
  const buttons = palettes.map((palette) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "palette-option";
    button.setAttribute("aria-pressed", "false");
    const swatch = document.createElement("span");
    swatch.className = "palette-swatch";
    swatch.style.setProperty("--swatch", palette.color);
    swatch.setAttribute("aria-hidden", "true");
    button.append(swatch, palette.name);
    button.addEventListener("click", () => applyPalette(palette.id, true));
    options.append(button);
    return button;
  });
  picker.append(options);
  document.body.append(picker);

  function applyPalette(requested, updateUrl = false) {
    const selected =
      palettes.find((palette) => palette.id === requested) || palettes[0];
    document.documentElement.dataset.palette = selected.id;
    current.textContent = selected.name;
    buttons.forEach((button, index) => {
      button.setAttribute(
        "aria-pressed",
        String(palettes[index].id === selected.id),
      );
    });
    try {
      localStorage.setItem(storageKey, selected.id);
    } catch {
      /* Optional storage. */
    }
    if (updateUrl) {
      const url = new URL(location.href);
      url.searchParams.set("palette", selected.id);
      history.replaceState(null, "", url);
    }
  }
  let saved;
  try {
    saved = localStorage.getItem(storageKey);
  } catch {
    /* Optional storage. */
  }
  applyPalette(new URLSearchParams(location.search).get("palette") || saved);
})();
