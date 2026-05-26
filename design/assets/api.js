/**
 * 크레딧-N 공통 API 클라이언트.
 * - localStorage 에 JWT 저장/복원
 * - fetch 를 감싸 자동 Authorization 헤더 부착
 * - 에러 응답을 throw 로 변환
 */
(function () {
  const API_BASE = window.__API_BASE__ || 'http://localhost:8080';
  const TOKEN_KEY = 'creditn.token';
  const USER_KEY  = 'creditn.user';

  /* ───────── 토큰 / 유저 관리 ───────── */
  const auth = {
    get token() { return localStorage.getItem(TOKEN_KEY); },
    set token(v) { v ? localStorage.setItem(TOKEN_KEY, v) : localStorage.removeItem(TOKEN_KEY); },

    get user() {
      const raw = localStorage.getItem(USER_KEY);
      return raw ? JSON.parse(raw) : null;
    },
    set user(v) {
      v ? localStorage.setItem(USER_KEY, JSON.stringify(v))
        : localStorage.removeItem(USER_KEY);
    },

    isLoggedIn() { return !!this.token; },
    clear() { this.token = null; this.user = null; }
  };

  /* ───────── 저수준 fetch 래퍼 ───────── */
  async function request(method, path, body) {
    const headers = { 'Content-Type': 'application/json' };
    if (auth.token) headers['Authorization'] = `Bearer ${auth.token}`;

    const res = await fetch(`${API_BASE}${path}`, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined
    });

    let payload = null;
    const text = await res.text();
    if (text) {
      try { payload = JSON.parse(text); }
      catch (_) { payload = text; }
    }

    if (!res.ok) {
      const message = (payload && payload.error) || res.statusText || 'request failed';
      const err = new Error(message);
      err.status = res.status;
      err.payload = payload;
      throw err;
    }
    return payload;
  }

  /* ───────── 도메인별 API ───────── */
  const api = {
    auth: {
      async signup(body) {
        const data = await request('POST', '/api/auth/signup', body);
        auth.token = data.token;
        auth.user  = { id: data.userId, username: data.username, linkScore: data.linkScore };
        return data;
      },
      async login(body) {
        const data = await request('POST', '/api/auth/login', body);
        auth.token = data.token;
        auth.user  = { id: data.userId, username: data.username, linkScore: data.linkScore };
        return data;
      },
      logout() { auth.clear(); }
    },

    moim: {
      create: (body) => request('POST', '/api/moims', body),
      join:   (inviteCode, refundAccountNumber, refundBank) => {
        const params = new URLSearchParams({ inviteCode });
        if (refundAccountNumber) params.set('refundAccountNumber', refundAccountNumber);
        if (refundBank)          params.set('refundBank', refundBank);
        return request('POST', `/api/moims/join?${params.toString()}`);
      },
      get:           (moimId) => request('GET', `/api/moims/${moimId}`),
      my:            ()       => request('GET', '/api/moims/my'),
      participants:  (moimId) => request('GET', `/api/moims/${moimId}/participants`),
      confirmDeposit:(moimId, userId) =>
                                request('POST', `/api/moims/${moimId}/deposit/confirm?userId=${userId}`),
      settle:        (moimId) => request('POST', `/api/moims/${moimId}/settle`)
    },

    payment: {
      pay:  (moimId, body) => request('POST', `/api/moims/${moimId}/payments`, body),
      list: (moimId)       => request('GET',  `/api/moims/${moimId}/payments`)
    }
  };

  /* ───────── 전역 노출 ───────── */
  window.CreditN = { api, auth, API_BASE };
})();
