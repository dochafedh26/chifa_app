// Espace Patient Clinique Chifa — Client Script
const _origin = window.location.origin;
const _pathname = window.location.pathname;

let API_BASE = `${_origin}/api`;
if (_pathname.includes('/chifa')) {
  API_BASE = `${_origin}/chifa/api`;
} else if (_pathname.includes('/portal')) {
  API_BASE = `${_origin}/portal/api`;
}

async function portalFetch(endpoint, options = {}) {
  const queryFallback = _pathname.includes('/chifa')
    ? `${_origin}/chifa/?route=${encodeURIComponent(endpoint)}`
    : `${_origin}/?route=${encodeURIComponent(endpoint)}`;

  const candidates = [
    `${_origin}/chifa/api${endpoint}`,
    `${_origin}/chifa${endpoint}`,
    queryFallback,
    `${_origin}/api${endpoint}`,
    `${_origin}/portal/api${endpoint}`,
  ];

  let lastRes = null;
  let lastErr = null;

  for (const url of candidates) {
    try {
      const res = await fetch(url, options);
      const contentType = res.headers.get('content-type') || '';
      // If server returned JSON or 401/403/400 API response, it's our Node backend!
      if (contentType.includes('application/json')) {
        return res;
      }
      lastRes = res;
    } catch (err) {
      lastErr = err;
    }
  }

  if (lastRes) return lastRes;
  throw lastErr || new Error('Impossible de joindre le serveur API');
}

// State
let currentToken = localStorage.getItem('chifa_patient_token');
let currentPatient = null;
try {
  currentPatient = JSON.parse(localStorage.getItem('chifa_patient_data') || 'null');
} catch (_) {}

// Elements
const loginSection = document.getElementById('loginSection');
const dashboardSection = document.getElementById('dashboardSection');
const patientProfile = document.getElementById('patientProfile');
const avatarInitials = document.getElementById('avatarInitials');
const patientNameDisplay = document.getElementById('patientNameDisplay');
const btnLogout = document.getElementById('btnLogout');

const loginForm = document.getElementById('loginForm');
const phoneInput = document.getElementById('phoneInput');
const pinInput = document.getElementById('pinInput');
const loginAlert = document.getElementById('loginAlert');

const navTabs = document.querySelectorAll('.nav-tab');
const tabContents = document.querySelectorAll('.tab-content');

const uploadForm = document.getElementById('uploadForm');
const fileInput = document.getElementById('fileInput');
const dropZone = document.getElementById('dropZone');
const selectedFileName = document.getElementById('selectedFileName');
const docCategory = document.getElementById('docCategory');
const docNotes = document.getElementById('docNotes');
const uploadAlert = document.getElementById('uploadAlert');
const uploadsListContainer = document.getElementById('uploadsListContainer');

const appointmentsContainer = document.getElementById('appointmentsContainer');
const prescriptionsContainer = document.getElementById('prescriptionsContainer');

const requestModal = document.getElementById('requestModal');
const btnOpenRequestModal = document.getElementById('btnOpenRequestModal');
const btnCloseModal = document.getElementById('btnCloseModal');
const btnCancelModal = document.getElementById('btnCancelModal');
const requestApptForm = document.getElementById('requestApptForm');
const modalAlert = document.getElementById('modalAlert');

// Initialization
  // Check URL params for auto-fill / auto-login (e.g. ?phone=0661234567&pin=1985)
  const urlParams = new URLSearchParams(window.location.search);
  const paramTel = urlParams.get('tel') || urlParams.get('phone') || urlParams.get('id') || urlParams.get('patient_id');
  const paramPin = urlParams.get('pin');

  if (paramTel && phoneInput) {
    phoneInput.value = paramTel;
  }
  if (paramPin && pinInput) {
    pinInput.value = paramPin;
  }

  setupEventListeners();

  if (currentToken && currentPatient) {
    showDashboard();
  } else {
    showLogin();
    // Auto-login if both phone and PIN are provided via URL parameters
    if (paramTel && paramPin && loginForm) {
      setTimeout(() => {
        loginForm.dispatchEvent(new Event('submit'));
      }, 150);
    } else if (paramTel && pinInput) {
      pinInput.focus();
    }
  }
});

function setupEventListeners() {
  // Login Form
  loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    loginAlert.classList.add('hidden');

    const phone = phoneInput.value.trim();
    const pin = pinInput.value.trim();

    try {
      const res = await portalFetch('/portal/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone, pin }),
      });
      const data = await res.json();

      if (!res.ok) {
        throw new Error(data.error || 'Identifiant ou code PIN incorrect.');
      }

      currentToken = data.token;
      currentPatient = data.patient;
      localStorage.setItem('chifa_patient_token', currentToken);
      localStorage.setItem('chifa_patient_data', JSON.stringify(currentPatient));

      showDashboard();
    } catch (err) {
      loginAlert.textContent = err.message;
      loginAlert.classList.remove('hidden');
    }
  });

  // Logout
  btnLogout.addEventListener('click', () => {
    localStorage.removeItem('chifa_patient_token');
    localStorage.removeItem('chifa_patient_data');
    currentToken = null;
    currentPatient = null;
    showLogin();
  });

  // Tabs
  navTabs.forEach((tab) => {
    tab.addEventListener('click', () => {
      navTabs.forEach((t) => t.classList.remove('active'));
      tabContents.forEach((c) => c.classList.remove('active'));

      tab.classList.add('active');
      const targetId = tab.getAttribute('data-tab');
      document.getElementById(targetId).classList.add('active');

      if (targetId === 'tab-appointments') loadAppointments();
      if (targetId === 'tab-prescriptions') loadPrescriptions();
      if (targetId === 'tab-upload') loadUploads();
    });
  });

  // Drag & drop file zone
  dropZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    dropZone.classList.add('hover');
  });
  dropZone.addEventListener('dragleave', () => dropZone.classList.remove('hover'));
  dropZone.addEventListener('drop', (e) => {
    e.preventDefault();
    dropZone.classList.remove('hover');
    if (e.dataTransfer.files.length) {
      fileInput.files = e.dataTransfer.files;
      handleFileSelected();
    }
  });
  fileInput.addEventListener('change', handleFileSelected);

  function handleFileSelected() {
    if (fileInput.files.length > 0) {
      const f = fileInput.files[0];
      selectedFileName.textContent = `Fichier sélectionné : ${f.name} (${(f.size / (1024 * 1024)).toFixed(2)} Mo)`;
      selectedFileName.classList.remove('hidden');
    }
  }

  // Upload Form Submit
  uploadForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    uploadAlert.classList.add('hidden');

    if (!fileInput.files.length) {
      showAlert(uploadAlert, 'Veuillez sélectionner un fichier.', 'error');
      return;
    }

    const formData = new FormData();
    formData.append('document', fileInput.files[0]);
    formData.append('category', docCategory.value);
    formData.append('notes', docNotes.value);

    const submitBtn = document.getElementById('btnSubmitUpload');
    submitBtn.disabled = true;
    submitBtn.innerHTML = '<span>Téléversement en cours...</span>';

    try {
      const res = await portalFetch('/portal/upload', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${currentToken}`,
        },
        body: formData,
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Erreur lors du téléversement');

      showAlert(uploadAlert, 'Résultat transmis avec succès ! Votre médecin a été immédiatement alerté.', 'success');
      uploadForm.reset();
      selectedFileName.classList.add('hidden');
      loadUploads();
    } catch (err) {
      showAlert(uploadAlert, err.message, 'error');
    } finally {
      submitBtn.disabled = false;
      submitBtn.innerHTML = `
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <line x1="22" y1="2" x2="11" y2="13"></line>
          <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
        </svg>
        <span>Envoyer au Médecin</span>
      `;
    }
  });

  // Modal Request Appointment
  btnOpenRequestModal.addEventListener('click', () => {
    requestModal.classList.remove('hidden');
    modalAlert.classList.add('hidden');
    // Default date = tomorrow
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    document.getElementById('reqDate').value = tomorrow.toISOString().split('T')[0];
  });

  const closeModal = () => requestModal.classList.add('hidden');
  btnCloseModal.addEventListener('click', closeModal);
  btnCancelModal.addEventListener('click', closeModal);

  requestApptForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    modalAlert.classList.add('hidden');

    const preferred_date = document.getElementById('reqDate').value;
    const preferred_time = document.getElementById('reqTime').value;
    const reason = document.getElementById('reqReason').value.trim();

    try {
      const res = await portalFetch('/portal/appointments/request', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${currentToken}`,
        },
        body: JSON.stringify({ preferred_date, preferred_time, reason }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Erreur');

      showAlert(modalAlert, 'Demande envoyée ! Le secrétariat vous recontactera rapidement.', 'success');
      setTimeout(() => {
        closeModal();
        loadAppointments();
      }, 1500);
    } catch (err) {
      showAlert(modalAlert, err.message, 'error');
    }
  });
}

function showLogin() {
  loginSection.classList.remove('hidden');
  dashboardSection.classList.add('hidden');
  patientProfile.classList.add('hidden');
}

function showDashboard() {
  loginSection.classList.add('hidden');
  dashboardSection.classList.remove('hidden');
  patientProfile.classList.remove('hidden');

  const fullName = `${currentPatient.first_name || ''} ${currentPatient.last_name || ''}`.trim() || 'Patient';
  patientNameDisplay.textContent = fullName;

  const initials = ((currentPatient.first_name?.[0] || '') + (currentPatient.last_name?.[0] || '')).toUpperCase() || 'P';
  avatarInitials.textContent = initials;

  loadUploads();
}

function showAlert(el, msg, type) {
  el.className = `alert-box ${type}`;
  el.textContent = msg;
  el.classList.remove('hidden');
}

// ─── API Loaders ─────────────────────────────────────────────────────────────

async function loadUploads() {
  try {
    uploadsListContainer.innerHTML = '<div class="loading-state">Chargement de vos documents...</div>';
    const res = await portalFetch('/portal/uploads', {
      headers: { Authorization: `Bearer ${currentToken}` },
    });
    const items = await res.json();

    if (!items.length) {
      uploadsListContainer.innerHTML = '<div class="loading-state">Aucun document téléversé pour le moment.</div>';
      return;
    }

    uploadsListContainer.innerHTML = items
      .map((item) => {
        const dateStr = new Date(item.created_at).toLocaleDateString('fr-FR', {
          day: 'numeric',
          month: 'short',
          year: 'numeric',
          hour: '2-digit',
          minute: '2-digit',
        });
        const isViewed = item.status === 'viewed';
        const badgeClass = isViewed ? 'viewed' : 'pending';
        const badgeLabel = isViewed ? '✓ Consulté par le médecin' : '⏳ Reçu par la clinique';

        return `
          <div class="upload-item">
            <div class="upload-info">
              <div class="upload-icon">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
                  <polyline points="14 2 14 8 20 8"></polyline>
                </svg>
              </div>
              <div>
                <div class="upload-name">${escapeHtml(item.original_name)}</div>
                <div class="upload-meta">${escapeHtml(item.category || 'Résultat')} • Transmis le ${dateStr}</div>
                ${item.notes ? `<div class="upload-meta" style="color:#0284c7;">Note: ${escapeHtml(item.notes)}</div>` : ''}
              </div>
            </div>
            <div>
              <span class="status-badge ${badgeClass}">${badgeLabel}</span>
            </div>
          </div>
        `;
      })
      .join('');
  } catch (err) {
    uploadsListContainer.innerHTML = `<div class="loading-state" style="color:var(--danger)">Erreur de chargement: ${err.message}</div>`;
  }
}

async function loadAppointments() {
  try {
    appointmentsContainer.innerHTML = '<div class="loading-state">Chargement de vos rendez-vous...</div>';
    const res = await portalFetch('/portal/appointments', {
      headers: { Authorization: `Bearer ${currentToken}` },
    });
    const items = await res.json();

    if (!items.length) {
      appointmentsContainer.innerHTML = '<div class="loading-state">Aucun rendez-vous planifié.</div>';
      return;
    }

    appointmentsContainer.innerHTML = items
      .map((item) => {
        const apptDate = new Date(item.appointment_date);
        const isUpcoming = apptDate >= new Date();
        const dateFormatted = apptDate.toLocaleDateString('fr-FR', {
          weekday: 'long',
          day: 'numeric',
          month: 'long',
          year: 'numeric',
          hour: '2-digit',
          minute: '2-digit',
        });

        return `
          <div class="appointment-card ${isUpcoming ? 'upcoming' : ''}">
            <div>
              <div class="appt-date">${dateFormatted}</div>
              <div class="appt-doctor">Médecin : ${escapeHtml(item.doctor_name || 'Équipe Médicale Chifa')}</div>
              ${item.notes ? `<div class="appt-notes">${escapeHtml(item.notes)}</div>` : ''}
            </div>
            <div>
              <span class="status-badge ${isUpcoming ? 'pending' : 'viewed'}">${escapeHtml(item.status)}</span>
            </div>
          </div>
        `;
      })
      .join('');
  } catch (err) {
    appointmentsContainer.innerHTML = `<div class="loading-state" style="color:var(--danger)">Erreur : ${err.message}</div>`;
  }
}

async function loadPrescriptions() {
  try {
    prescriptionsContainer.innerHTML = '<div class="loading-state">Chargement de vos ordonnances...</div>';
    const res = await portalFetch('/portal/prescriptions', {
      headers: { Authorization: `Bearer ${currentToken}` },
    });
    const items = await res.json();

    if (!items.length) {
      prescriptionsContainer.innerHTML = '<div class="loading-state">Aucune ordonnance archivée.</div>';
      return;
    }

    prescriptionsContainer.innerHTML = items
      .map((item) => {
        const dateFormatted = new Date(item.date).toLocaleDateString('fr-FR', {
          day: 'numeric',
          month: 'long',
          year: 'numeric',
        });
        return `
          <div class="prescription-card">
            <div class="presc-header">
              <span>Ordonnance délivrée le ${dateFormatted}</span>
              ${item.doctor_name ? `<span>Dr. ${escapeHtml(item.doctor_name)}</span>` : ''}
            </div>
            <div class="presc-body">${escapeHtml(item.prescription || 'Contenu')}</div>
          </div>
        `;
      })
      .join('');
  } catch (err) {
    prescriptionsContainer.innerHTML = `<div class="loading-state" style="color:var(--danger)">Erreur : ${err.message}</div>`;
  }
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

