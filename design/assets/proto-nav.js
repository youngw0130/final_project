/**
 * 프로토타입 화면 공통 네비게이션 배너.
 * - 우상단에 "← 허브 / ▶ API 데모" 플로팅 버튼 주입
 * - 로그인된 사용자가 있으면 화면 안의 [data-bind-username] / [data-bind-linkscore] 요소를 실제 값으로 치환
 *
 * 사용법: prototype HTML 안에 한 줄만 추가
 *   <script src="../assets/api.js"></script>
 *   <script src="../assets/proto-nav.js"></script>
 */
(function () {
  const bar = document.createElement('div');
  bar.style.cssText = `
    position: fixed; top: 12px; right: 12px; z-index: 9999;
    display: flex; gap: 8px; align-items: center;
    background: rgba(15,23,42,0.92); color: #fff;
    padding: 6px 10px; border-radius: 999px;
    font-family: 'Pretendard', -apple-system, sans-serif;
    font-size: 12px; font-weight: 600;
    box-shadow: 0 8px 24px rgba(0,0,0,0.18);
    backdrop-filter: blur(6px);
  `;
  bar.innerHTML = `
    <a href="../index.html" style="color:#cbd5e1;text-decoration:none;padding:4px 8px;">← 허브</a>
    <span style="opacity:.4">|</span>
    <a href="../demo.html"  style="color:#a5b4fc;text-decoration:none;padding:4px 8px;">▶ API 데모</a>
    <span id="proto-nav-user" style="display:none;margin-left:6px;padding:3px 8px;background:#10b981;border-radius:999px;font-size:11px;"></span>
  `;
  document.body.appendChild(bar);

  function applyBindings() {
    const u = window.CreditN && window.CreditN.auth && window.CreditN.auth.user;
    if (!u) return;

    document.querySelectorAll('[data-bind-username]').forEach(el => { el.textContent = u.username; });
    document.querySelectorAll('[data-bind-linkscore]').forEach(el => { el.textContent = u.linkScore ?? '-'; });

    const badge = document.getElementById('proto-nav-user');
    if (badge) {
      badge.style.display = 'inline-block';
      badge.textContent = `${u.username} · ${u.linkScore ?? '-'}`;
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', applyBindings);
  } else {
    applyBindings();
  }

  window.addEventListener('creditn:authed', applyBindings);
})();
