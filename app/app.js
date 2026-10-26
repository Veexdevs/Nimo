// ============================================================
// NIMO — interações básicas da interface (apenas visual)
// ============================================================

const input = document.getElementById("messageInput");
const messages = document.getElementById("messages");

// Enviar mensagem (apenas visual, sem backend ainda)
input.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && input.value.trim() !== "") {
    const text = input.value.trim();
    input.value = "";

    const now = new Date();
    const hora = now.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });

    const msg = document.createElement("div");
    msg.className = "message";
    msg.innerHTML = `
      <span class="msg-avatar nimo"><img src="assets/logo-icon.png" alt="Você" /></span>
      <div class="msg-content">
        <div class="msg-header">
          <span class="msg-author c4">Você</span>
          <span class="msg-time">Hoje às ${hora}</span>
        </div>
        <p></p>
      </div>
    `;
    msg.querySelector("p").textContent = text; // seguro contra HTML
    messages.appendChild(msg);
    messages.scrollTop = messages.scrollHeight;
  }
});

// Troca de canal ativo (visual)
document.querySelectorAll(".channel").forEach((ch) => {
  ch.addEventListener("click", () => {
    if (ch.classList.contains("voice")) return; // canais de voz não trocam o chat por enquanto
    document.querySelectorAll(".channel").forEach((c) => c.classList.remove("active"));
    ch.classList.add("active");
    ch.querySelector(".ch-unread")?.remove();

    const name = ch.querySelector(".ch-name").textContent;
    document.querySelector(".chat-title h2").textContent = name;
    input.placeholder = `Conversar em #${name}`;
  });
});

// Troca de servidor ativo (visual) + alternância Mensagens/Servidor
const app = document.getElementById("app");

document.querySelectorAll(".rail-item.home, .rail-item.server").forEach((s) => {
  s.addEventListener("click", () => {
    document.querySelectorAll(".rail-item").forEach((r) => r.classList.remove("active"));
    s.classList.add("active");

    if (s.classList.contains("home")) {
      app.classList.add("dm-mode"); // tela de Mensagens (DMs)
    } else {
      app.classList.remove("dm-mode"); // tela do servidor
    }
  });
});

// Começa na tela de Mensagens (logo Nimo ativa)
if (document.querySelector(".rail-item.home.active")) {
  app.classList.add("dm-mode");
}

// Reações (visual)
document.querySelectorAll(".reaction:not(.add)").forEach((r) => {
  r.addEventListener("click", () => {
    const count = r.querySelector("b");
    const n = parseInt(count.textContent, 10);
    if (r.classList.toggle("active")) {
      count.textContent = n + 1;
    } else {
      count.textContent = n - 1;
    }
  });
});

// Rolar para o fim ao abrir
messages.scrollTop = messages.scrollHeight;
