/* Ars Hortensis – weboldal logika: görgetős képsorozat + ajánlatkérő ársávval. */
(function () {
  'use strict';

  /* ---------- Árbeállítások (PÉLDAÁRAK – a végleges árlista után frissítendő) ---------- */
  var PRICES = {
    perM2: 48000,          // Ft/m², szárazkert, ajánlott szint
    custosPerM2: 160,      // Ft/m²/hó, Custos, ajánlott szint
    custosMin: 35000,      // Ft/hó minimum
    types: {
      terv:   { label: 'Kerttervezés', f: 0.07, min: 250000 },
      szaraz: { label: 'Szárazkert, sziklakert', f: 1.0, min: 0 },
      teljes: { label: 'Teljes kertépítés', f: 0.85, min: 0 },
      custos: { label: 'Custos gondozás', f: 0, min: 0 }
    },
    levels: {
      alap:     { label: 'Alap', m: 0.7 },
      ajanlott: { label: 'Ajánlott', m: 1.0 },
      premium:  { label: 'Prémium', m: 1.5 }
    }
  };
  var ENDPOINT = '/api/ajanlat';

  /* ---------- Görgetésre lejátszódó képsorozat ---------- */
  var wrap = document.getElementById('seqScroll');
  if (wrap) {
    var n = parseInt(wrap.getAttribute('data-frames') || '0', 10);
    var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (n > 1) {
      var path = wrap.getAttribute('data-path'), ext = wrap.getAttribute('data-ext') || '.webp';
      var canvas = document.getElementById('seqCanvas'), ctx = canvas.getContext('2d');
      var ph = document.getElementById('seqPh');
      var imgs = new Array(n), cur = -1;
      var src = function (i) { return path + String(i + 1).padStart(4, '0') + ext; };
      var draw = function (i) {
        var img = imgs[i];
        if (!img || !img.complete || !img.naturalWidth) return;
        var r = canvas.getBoundingClientRect(), dpr = Math.min(2, window.devicePixelRatio || 1);
        if (canvas.width !== Math.round(r.width * dpr)) { canvas.width = Math.round(r.width * dpr); canvas.height = Math.round(r.height * dpr); }
        var s = Math.max(canvas.width / img.naturalWidth, canvas.height / img.naturalHeight);
        var w = img.naturalWidth * s, h = img.naturalHeight * s;
        ctx.drawImage(img, (canvas.width - w) / 2, (canvas.height - h) / 2, w, h);
        if (ph) { ph.remove(); ph = null; }
      };
      var load = function (i) { if (imgs[i]) return; var im = new Image(); im.decoding = 'async'; im.onload = function () { if (i === cur || cur < 0) draw(i); }; im.src = src(i); imgs[i] = im; };
      load(0); cur = 0;
      if (reduce) { load(n - 1); cur = n - 1; }
      else {
        wrap.classList.add('is-scroll');
        for (var k = 1; k < n; k += 4) load(k);
        var onScroll = function () {
          var r = wrap.getBoundingClientRect(), span = r.height - window.innerHeight;
          var p = span > 0 ? Math.min(1, Math.max(0, -r.top / span)) : 0;
          var i = Math.min(n - 1, Math.round(p * (n - 1)));
          if (i !== cur) { cur = i; load(i); draw(i); }
        };
        window.addEventListener('scroll', function () { window.requestAnimationFrame(onScroll); }, { passive: true });
        window.addEventListener('resize', function () { canvas.width = 0; draw(cur); });
        setTimeout(function () { for (var j = 0; j < n; j++) load(j); }, 1500);
      }
    }
  }

  /* ---------- Ajánlatkérő ---------- */
  var form = document.getElementById('qForm');
  if (!form) return;
  var st = { step: 0, type: 'szaraz', level: 'ajanlott', area: 120 };
  var steps = form.querySelectorAll('.q-step');
  var bar = document.getElementById('qBar'), back = document.getElementById('qBack'), next = document.getElementById('qNext');
  var areaIn = document.getElementById('qArea'), areaOut = document.getElementById('qAreaOut');
  var priceEl = document.getElementById('qPrice'), noteEl = document.getElementById('qPriceNote'), sumEl = document.getElementById('qSummary');
  var errEl = document.getElementById('qErr');
  var fmt = function (v) { return (Math.round(v / 10000) * 10000).toLocaleString('hu-HU'); };

  function price() {
    var T = PRICES.types[st.type], L = PRICES.levels[st.level];
    if (st.type === 'custos') {
      var mo = Math.max(PRICES.custosMin, st.area * PRICES.custosPerM2 * L.m);
      return { text: fmt(mo * 0.9) + ' – ' + fmt(mo * 1.15) + ' Ft/hó', note: 'Nettó, + ÁFA, márciustól novemberig. A pontos díjat a bejárás után adjuk.', low: mo * 0.9, high: mo * 1.15 };
    }
    var v = Math.max(st.area * PRICES.perM2 * L.m * T.f, T.min);
    return { text: fmt(v * 0.88) + ' – ' + fmt(v * 1.15) + ' Ft', note: 'Nettó, + ÁFA. A fix árat a helyszíni felmérés után, 24 órán belül adjuk.', low: v * 0.88, high: v * 1.15 };
  }
  function render() {
    steps.forEach(function (s, i) { s.classList.toggle('on', i === st.step); });
    bar.style.width = ((st.step + 1) * 25) + '%';
    back.disabled = st.step === 0;
    next.textContent = st.step === 3 ? 'Ajánlatkérés elküldése' : 'Tovább';
    var p = price();
    priceEl.textContent = p.text; noteEl.textContent = p.note;
    sumEl.textContent = PRICES.types[st.type].label + ' · ' + st.area + ' m² · ' + PRICES.levels[st.level].label;
  }
  form.querySelectorAll('.opts').forEach(function (g) {
    var key = g.getAttribute('data-group');
    g.addEventListener('click', function (e) {
      var b = e.target.closest('.opt'); if (!b) return;
      st[key] = b.getAttribute('data-v');
      g.querySelectorAll('.opt').forEach(function (o) { o.setAttribute('aria-pressed', o === b ? 'true' : 'false'); });
      render();
    });
  });
  areaIn.addEventListener('input', function () { st.area = parseInt(areaIn.value, 10); areaOut.textContent = st.area; render(); });
  document.getElementById('qZip').addEventListener('input', function (e) { e.target.value = e.target.value.replace(/\D/g, '').slice(0, 4); });
  back.addEventListener('click', function () { if (st.step > 0) { st.step--; errEl.hidden = true; render(); } });
  next.addEventListener('click', function () {
    if (st.step < 3) { st.step++; render(); steps[st.step].querySelector('button, input') && steps[st.step].querySelector('button, input').focus(); return; }
    var fd = new FormData(form);
    var name = (fd.get('name') || '').trim(), email = (fd.get('email') || '').trim(), phone = (fd.get('phone') || '').trim();
    var ok = name.length > 1 && (/@/.test(email) || phone.length > 5) && fd.get('consent');
    if (!ok) { errEl.hidden = false; return; }
    errEl.hidden = true; next.disabled = true; next.textContent = 'Küldés…';
    var p = price();
    var payload = { tipus: st.type, terulet_m2: st.area, szint: st.level, arsav_also: Math.round(p.low), arsav_felso: Math.round(p.high),
      nev: name, email: email, telefon: phone, iranyitoszam: fd.get('zip') || '', megjegyzes: fd.get('note') || '',
      hozzajarulas: true, forras: 'weboldal', website: fd.get('website') || '' };
    fetch(ENDPOINT, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) })
      .then(function (r) { if (!r.ok) throw new Error(r.status); done(); })
      .catch(function () {
        next.disabled = false; next.textContent = 'Újrapróbálom';
        errEl.textContent = 'A küldés most nem sikerült. Kérjük, próbálja újra, vagy írjon nekünk: [E-MAIL] · [TELEFON].';
        errEl.hidden = false;
      });
  });
  function done() {
    steps.forEach(function (s) { s.classList.remove('on'); });
    document.getElementById('qNav').hidden = true;
    document.getElementById('qDone').classList.add('on');
    bar.style.width = '100%';
  }
  render();
})();
