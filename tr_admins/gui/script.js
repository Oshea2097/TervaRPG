document.addEventListener("DOMContentLoaded", () => {
  const buttons = document.querySelectorAll(".menu-btn");
  const sections = document.querySelectorAll(".section");
  const closeBtn = document.getElementById("closePanel");

  buttons.forEach(btn => {
    btn.addEventListener("click", () => {
      buttons.forEach(b => b.classList.remove("active"));
      btn.classList.add("active");

      const target = btn.getAttribute("data-section");
      sections.forEach(sec => sec.classList.remove("active"));
      document.getElementById(target).classList.add("active");
    });
  });

  closeBtn.addEventListener("click", () => {
    if (typeof mta !== "undefined") {
      mta.triggerEvent("closeAdminPanel");
    }
  });
});
