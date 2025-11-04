function initAdminPanel(data) {
  document.getElementById("username").innerText = data.username || "Nieznany";
  document.getElementById("rank").innerText = data.rank || "Brak";
  document.getElementById("lastLogin").innerText = data.lastLogin || "Nigdy";
  document.getElementById("close").addEventListener("click", () => mta.triggerEvent("admin:closePanel"));
  requestPlayers();
}

function showSection(id) {
  document.querySelectorAll("section").forEach(s => s.classList.add("hidden"));
  document.getElementById(id).classList.remove("hidden");
}

function requestPlayers() { mta.triggerEvent("admin:requestPlayers"); }

function updatePlayers(players) {
  const tbody = document.querySelector("#playerTable tbody");
  tbody.innerHTML = "";
  players.forEach(p => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${p.name}</td>
      <td>${p.id}</td>
      <td>
        <button onclick="adminAction('tpTo', '${p.name}')">TP Do</button>
        <button onclick="adminAction('tpHere', '${p.name}')">TP Tu</button>
        <button onclick="adminAction('mute', '${p.name}')">Mute</button>
        <button onclick="adminAction('kick', '${p.name}')">Kick</button>
      </td>`;
    tbody.appendChild(tr);
  });
}

function adminAction(action, target) { mta.triggerEvent("admin:action", action, target); }

function notify(msg) { alert(msg); }
