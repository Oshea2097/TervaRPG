function initAdminPanel(data) {
  document.getElementById("username").innerText = data.username || "Nieznany";
  document.getElementById("rank").innerText = data.rank || "Brak";
  document.getElementById("lastLogin").innerText = data.lastLogin || "Nigdy";

  document.getElementById("close").addEventListener("click", () => {
    mta.triggerEvent("admin:closePanel");
  });
}
