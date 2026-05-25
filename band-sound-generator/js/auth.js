'use strict';

// Login con Google (Google Identity Services).
// Pega el Client ID de OAuth 2.0 (Web application) en GOOGLE_CLIENT_ID.
// Si lo dejas vacío, el login se omite (modo desarrollo).
//
// Cómo obtenerlo: README -> sección "Configurar el login de Google".
const GOOGLE_CLIENT_ID = '548451539953-pvdr0bv3hbpi1hsapva5cefqodvrkoth.apps.googleusercontent.com';

const AUTH_STORE_KEY = 'band-sound-generator:user';

(function () {
  const overlay = document.getElementById('login-overlay');
  const btnHost = document.getElementById('gsi-button');
  const userBox = document.getElementById('user-box');
  const userName = document.getElementById('user-name');
  const userAvatar = document.getElementById('user-avatar');
  const signOutBtn = document.getElementById('sign-out');
  const authError = document.getElementById('auth-error');

  function isLocked() {
    return overlay && overlay.style.display !== 'none';
  }

  // Bloquea teclado y clicks mientras la capa de login está visible.
  ['keydown', 'keyup', 'pointerdown'].forEach((evt) => {
    document.addEventListener(
      evt,
      (e) => {
        if (!isLocked()) return;
        if (overlay.contains(e.target)) return;
        e.stopImmediatePropagation();
      },
      true,
    );
  });

  function decodeJwt(token) {
    try {
      const b64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      const json = decodeURIComponent(
        atob(b64)
          .split('')
          .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
          .join(''),
      );
      return JSON.parse(json);
    } catch (e) {
      return null;
    }
  }

  function showUser(user) {
    overlay.style.display = 'none';
    userBox.style.display = 'flex';
    userName.textContent = user.name || user.email || '';
    if (user.picture) {
      userAvatar.src = user.picture;
      userAvatar.alt = user.name || '';
      userAvatar.style.display = '';
    } else {
      userAvatar.style.display = 'none';
    }
  }

  function signOut() {
    try {
      localStorage.removeItem(AUTH_STORE_KEY);
    } catch (e) {
      /* noop */
    }
    if (window.google && google.accounts && google.accounts.id) {
      google.accounts.id.disableAutoSelect();
    }
    location.reload();
  }

  signOutBtn.addEventListener('click', signOut);

  // Sesión recordada y aún no expirada.
  try {
    const cached = localStorage.getItem(AUTH_STORE_KEY);
    if (cached) {
      const user = JSON.parse(cached);
      if (user && user.exp && user.exp * 1000 > Date.now()) {
        showUser(user);
        return;
      }
      localStorage.removeItem(AUTH_STORE_KEY);
    }
  } catch (e) {
    /* noop */
  }

  // Modo desarrollo: sin Client ID configurado, se omite el login.
  if (!GOOGLE_CLIENT_ID) {
    overlay.style.display = 'none';
    return;
  }

  function onCredential(response) {
    const payload = decodeJwt(response && response.credential);
    if (!payload || !payload.sub) {
      if (authError) authError.textContent = 'No se pudo leer la credencial de Google.';
      return;
    }
    const user = {
      name: payload.name,
      email: payload.email,
      picture: payload.picture,
      sub: payload.sub,
      exp: payload.exp,
    };
    try {
      localStorage.setItem(AUTH_STORE_KEY, JSON.stringify(user));
    } catch (e) {
      /* almacenamiento no disponible */
    }
    showUser(user);
  }

  // Espera a que la librería de GSI cargue (script async).
  let waited = 0;
  function init() {
    if (!window.google || !google.accounts || !google.accounts.id) {
      if (waited > 8000) {
        if (authError) authError.textContent = 'No se pudo cargar Google Identity. Revisa la conexión.';
        return;
      }
      waited += 100;
      return setTimeout(init, 100);
    }
    try {
      google.accounts.id.initialize({
        client_id: GOOGLE_CLIENT_ID,
        callback: onCredential,
        auto_select: false,
        cancel_on_tap_outside: true,
      });
      google.accounts.id.renderButton(btnHost, {
        theme: 'filled_blue',
        size: 'large',
        shape: 'pill',
        text: 'signin_with',
        logo_alignment: 'left',
      });
    } catch (e) {
      if (authError) authError.textContent = 'Error al inicializar Google Sign-In: ' + e.message;
    }
  }
  init();
})();
