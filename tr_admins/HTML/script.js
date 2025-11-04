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

// Update players table
function updatePlayers(players) {
  const tbody = document.querySelector("#playerTable tbody");
  tbody.innerHTML = "";
  players.forEach(p => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${p.name}</td>
      <td>${p.tid}</td>
      <td>
        <button onclick="adminAction('tpTo', { name: '${p.name}' })">TP Do</button>
        <button onclick="adminAction('tpHere', { name: '${p.name}' })">TP Tu</button>
        <button onclick="selectTarget('${p.name}')">Wybierz</button>
      </td>`;
    tbody.appendChild(tr);
  });
}

function selectTarget(name) {
  document.getElementById("punishTarget").value = name;
  showSection('punishments');
}

// Admin action via client bridge
function adminAction(action, payload) {
  // payload must be an object
  mta.triggerEvent("admin:clientAction", action, payload);
}

// Submit punish form
function submitPunishment() {
  const target = document.getElementById("punishTarget").value.trim();
  const type = document.getElementById("punishType").value;
  const minutes = parseInt(document.getElementById("punishMinutes").value) || 0;
  const reason = document.getElementById("punishReason").value || "";

  if (!target) { alert("Podaj nick celu."); return; }

  // payload: name + minutes + reason
  const payload = { name: target, minutes: minutes, reason: reason };
  adminAction(type, payload); // e.g. action 'ban' with payload
  // simple UI log
  const log = document.getElementById("punishLog");
  const now = new Date().toLocaleString();
  log.innerHTML = `<p>[${now}] Wysłano ${type} dla ${target} (${minutes} min) - ${reason}</p>` + log.innerHTML;
}

// JS receive functions from Lua
function updatePlayersFromLua(players) { updatePlayers(players); }
function notify(msg) { alert(msg); }

// Bridge to MTA: add global handlers for executeBrowserJavascript calls
window.receiveFromLua = function(name, payload) {
  if (name === "playersList") updatePlayers(payload);
  if (name === "notify") notify(payload);
};
