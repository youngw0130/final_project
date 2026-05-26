/**
 * 로그인 가드 + 공통 유틸.
 * - 페이지 로딩 시 로그인 안 되어 있으면 자동 로그인 모달 표시
 * - localStorage 에 selectedMoimId 보관해 화면 간 전달
 * - 공통 fmt: 금액/날짜 포매터
 */
(function () {
  const SEL_MOIM_KEY = 'creditn.selectedMoimId';

  /* ───────── 공통 유틸 ───────── */
  const fmt = {
    won(n) {
      if (n == null || isNaN(n)) return '0';
      return Number(n).toLocaleString('ko-KR');
    },
    wonShort(n) {
      const v = Number(n) || 0;
      return v.toLocaleString('ko-KR') + '원';
    },
    pct(n) {
      if (n == null || isNaN(n)) return '0';
      return Number(n).toFixed(1);
    },
    relTime(isoStr) {
      if (!isoStr) return '';
      const d = new Date(isoStr);
      const diffMs = Date.now() - d.getTime();
      const min = Math.floor(diffMs / 60000);
      if (min < 1) return '방금';
      if (min < 60) return `${min}분 전`;
      const hr = Math.floor(min / 60);
      if (hr < 24) return `${hr}시간 전`;
      const day = Math.floor(hr / 24);
      if (day < 7) return `${day}일 전`;
      return d.toLocaleDateString('ko-KR', { month: 'numeric', day: 'numeric' });
    },
    dateTime(isoStr) {
      if (!isoStr) return '';
      const d = new Date(isoStr);
      return d.toLocaleString('ko-KR', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' });
    },
    short2(name) {
      if (!name) return '?';
      const trimmed = String(name).trim();
      if (trimmed.length <= 2) return trimmed;
      return trimmed.slice(-2);
    }
  };

  const state = {
    get selectedMoimId() {
      const v = localStorage.getItem(SEL_MOIM_KEY);
      return v ? Number(v) : null;
    },
    set selectedMoimId(v) {
      v ? localStorage.setItem(SEL_MOIM_KEY, String(v)) : localStorage.removeItem(SEL_MOIM_KEY);
    }
  };

  /* ───────── 로그인 모달 ───────── */
  function showLoginModal() {
    if (document.getElementById('cn-login-modal')) return;

    const wrap = document.createElement('div');
    wrap.id = 'cn-login-modal';
    wrap.style.cssText = `
      position: fixed; inset: 0; z-index: 99999;
      background: rgba(15,23,42,0.65); backdrop-filter: blur(6px);
      display: flex; align-items: center; justify-content: center;
      font-family: 'Pretendard', -apple-system, sans-serif;
    `;
    wrap.innerHTML = `
      <div style="
        background: white; border-radius: 24px; padding: 28px;
        width: 92%; max-width: 360px;
        box-shadow: 0 24px 64px rgba(0,0,0,0.25);
      ">
        <div style="text-align:center; margin-bottom: 22px;">
          <div style="
            width: 56px; height: 56px; margin: 0 auto 12px;
            border-radius: 16px;
            background: linear-gradient(135deg,#0052FF,#3B82F6);
            display: flex; align-items: center; justify-content: center;
            color: white; font-size: 26px; font-weight: 800;">C</div>
          <h2 style="margin:0; font-size:18px; font-weight:800; color:#0F172A;">크레딧-N 로그인</h2>
          <p style="margin:6px 0 0; font-size:12px; color:#64748B;">
            서비스 데모를 시작하려면 로그인해주세요
          </p>
        </div>

        <div style="display:flex; flex-direction:column; gap:10px;">
          <input id="cn-login-id" placeholder="아이디" value="감나빗"
            style="border:1.5px solid #E2E8F0;border-radius:12px;padding:12px 14px;font-size:14px;outline:none;font-family:inherit;" />
          <input id="cn-login-pw" placeholder="비밀번호" value="test1234" type="password"
            style="border:1.5px solid #E2E8F0;border-radius:12px;padding:12px 14px;font-size:14px;outline:none;font-family:inherit;" />
          <div id="cn-login-err" style="font-size:12px;color:#DC2626;min-height:16px;"></div>

          <button id="cn-login-btn"
            style="background:linear-gradient(90deg,#0038CC,#0052FF);color:white;font-weight:700;
                   padding:13px;border:0;border-radius:12px;font-size:14px;cursor:pointer;
                   box-shadow:0 6px 18px rgba(0,82,255,.32);font-family:inherit;">
            로그인
          </button>

          <div style="text-align:center;font-size:11px;color:#94A3B8;margin-top:4px;">
            데모 계정: 감나빗 · minsu · sora · hyunwoo · seoyeon (비번 test1234)
          </div>
        </div>
      </div>
    `;
    document.body.appendChild(wrap);

    const idEl = wrap.querySelector('#cn-login-id');
    const pwEl = wrap.querySelector('#cn-login-pw');
    const errEl = wrap.querySelector('#cn-login-err');
    const btn = wrap.querySelector('#cn-login-btn');

    async function doLogin() {
      errEl.textContent = '';
      btn.disabled = true;
      btn.textContent = '로그인 중...';
      try {
        await window.CreditN.api.auth.login({
          username: idEl.value.trim(),
          password: pwEl.value
        });
        wrap.remove();
        window.dispatchEvent(new Event('creditn:authed'));
      } catch (e) {
        errEl.textContent = e.message || '로그인 실패';
        btn.disabled = false;
        btn.textContent = '로그인';
      }
    }

    btn.addEventListener('click', doLogin);
    [idEl, pwEl].forEach(el => el.addEventListener('keydown', e => {
      if (e.key === 'Enter') doLogin();
    }));
  }

  /* ───────── 페이지 init helper ───────── */
  function requireAuth(callback) {
    function start() {
      if (!window.CreditN || !window.CreditN.api) {
        setTimeout(start, 50);
        return;
      }
      if (window.CreditN.auth && window.CreditN.auth.isLoggedIn()) {
        callback();
      } else {
        showLoginModal();
        window.addEventListener('creditn:authed', callback, { once: true });
      }
    }
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', start);
    } else {
      start();
    }
  }

  /* ───────── 전역 노출 ───────── */
  window.CN = { fmt, state, requireAuth, showLoginModal };
})();
