// TV Waiting Room Display Script - Clinique Chifa
let lastCalledId = null;
let isAudioEnabled = true;

const clockTimeEl = document.getElementById('clockTime');
const clockDateEl = document.getElementById('clockDate');
const ticketNumberEl = document.getElementById('ticketNumber');
const patientNameEl = document.getElementById('patientName');
const targetCabinetEl = document.getElementById('targetCabinet');
const queueCountEl = document.getElementById('queueCount');
const queueListEl = document.getElementById('queueList');
const tickerTextEl = document.getElementById('tickerText');
const btnFullscreen = document.getElementById('btnFullscreen');
const btnAudioToggle = document.getElementById('btnAudioToggle');

// 1. Live Clock
function updateClock() {
  const now = new Date();
  const timeStr = now.toLocaleTimeString('fr-FR', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
  const dateStr = now.toLocaleDateString('fr-FR', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });

  if (clockTimeEl) clockTimeEl.textContent = timeStr;
  if (clockDateEl) clockDateEl.textContent = dateStr.toUpperCase();
}
setInterval(updateClock, 1000);
updateClock();

// 2. Health Tips Ticker
const tips = [
  'Bienvenue à la Clinique Chifa • Nous prenons soin de votre santé.',
  'Merci de préparer votre carte d\'assuré et vos ordonnances récentes.',
  'En cas d\'urgence médicale signalée, veuillez avertir l\'accueil immédiatement.',
  'Veuillez respecter le calme et couper la sonnerie de votre téléphone.',
  'Le port du masque reste recommandé en cas de symptômes respiratoires.',
  'Consultez vos bilans et ordonnances en ligne sur medevsync.com/chifa',
];
let tipIndex = 0;
setInterval(() => {
  tipIndex = (tipIndex + 1) % tips.length;
  if (tickerTextEl) {
    tickerTextEl.style.opacity = '0';
    setTimeout(() => {
      tickerTextEl.textContent = tips[tipIndex];
      tickerTextEl.style.opacity = '1';
    }, 400);
  }
}, 12000);

// 3. Audio Chime (Synthesized Ding-Dong using Web Audio API)
function playChime() {
  if (!isAudioEnabled) return;

  try {
    const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    
    // Note 1: High tone
    const osc1 = audioCtx.createOscillator();
    const gain1 = audioCtx.createGain();
    osc1.type = 'sine';
    osc1.frequency.setValueAtTime(659.25, audioCtx.currentTime); // E5
    gain1.gain.setValueAtTime(0.3, audioCtx.currentTime);
    gain1.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.8);
    osc1.connect(gain1);
    gain1.connect(audioCtx.destination);
    osc1.start();
    osc1.stop(audioCtx.currentTime + 0.8);

    // Note 2: Chime resolve (Ding - Dong)
    setTimeout(() => {
      const osc2 = audioCtx.createOscillator();
      const gain2 = audioCtx.createGain();
      osc2.type = 'sine';
      osc2.frequency.setValueAtTime(523.25, audioCtx.currentTime); // C5
      gain2.gain.setValueAtTime(0.35, audioCtx.currentTime);
      gain2.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 1.2);
      osc2.connect(gain2);
      gain2.connect(audioCtx.destination);
      osc2.start();
      osc2.stop(audioCtx.currentTime + 1.2);
    }, 300);
  } catch (e) {
    console.warn('Audio Context error:', e);
  }
}

// 4. API Fetching
async function fetchQueue() {
  const candidates = [
    '/chifa/api/tv/waiting-room',
    '/api/tv/waiting-room',
    '/tv/api/waiting-room',
    '/chifa/tv/waiting-room',
  ];

  let data = null;
  for (const url of candidates) {
    try {
      const res = await fetch(url);
      if (res.ok) {
        data = await res.json();
        break;
      }
    } catch (_) {}
  }

  if (!data) return;

  // Update Called Patient
  if (data.called_patient) {
    const p = data.called_patient;
    ticketNumberEl.textContent = `TICKET N° ${String(p.ticket).padStart(2, '0')}`;
    patientNameEl.textContent = p.masked_name;
    targetCabinetEl.textContent = p.cabinet ? p.cabinet.toUpperCase() : 'CABINET N° 1';

    // Play chime if patient changed
    if (lastCalledId !== p.id) {
      if (lastCalledId !== null) {
        playChime();
      }
      lastCalledId = p.id;
    }
  } else {
    ticketNumberEl.textContent = 'TICKET N° --';
    patientNameEl.textContent = 'AUCUN PATIENT APPELÉ';
    targetCabinetEl.textContent = 'CABINET DE CONSULTATION';
    lastCalledId = null;
  }

  // Update Queue List
  const queue = data.waiting_queue || [];
  queueCountEl.textContent = `${queue.length} en attente`;

  if (queue.length === 0) {
    queueListEl.innerHTML = '<div class="empty-queue">Aucun patient en file d\'attente</div>';
  } else {
    queueListEl.innerHTML = queue
      .map((item) => {
        const isActive = data.called_patient && data.called_patient.id === item.id;
        return `
          <div class="queue-item ${isActive ? 'active' : ''}">
            <div class="queue-ticket">#${item.ticket}</div>
            <div class="queue-patient-info">
              <div class="queue-name">${item.masked_name}</div>
              <div class="queue-time">Arrivé à ${item.time}</div>
            </div>
            ${isActive ? '<span style="color:#22c55e;font-weight:900;font-size:0.85rem">APPELÉ</span>' : ''}
          </div>
        `;
      })
      .join('');
  }
}

// 5. Poll every 3.5s
setInterval(fetchQueue, 3500);
fetchQueue();

// 6. Audio Toggle & Fullscreen Controls
if (btnAudioToggle) {
  btnAudioToggle.addEventListener('click', () => {
    isAudioEnabled = !isAudioEnabled;
    btnAudioToggle.textContent = isAudioEnabled ? '🔔 Sonnerie Activée' : '🔕 Sonnerie Coupée';
    btnAudioToggle.style.color = isAudioEnabled ? '#38bdf8' : '#ef4444';
  });
}

if (btnFullscreen) {
  btnFullscreen.addEventListener('click', () => {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().catch(() => {});
    } else {
      document.exitFullscreen().catch(() => {});
    }
  });
}

