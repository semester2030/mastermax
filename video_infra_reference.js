(() => {
  const viewsInput = document.getElementById("viewsPerDay");
  const minutesInput = document.getElementById("minutesPerView");
  const libraryMinutesInput = document.getElementById("libraryMinutes");
  const btn = document.getElementById("calcBtn");
  const results = document.getElementById("calcResults");
  const topicCards = document.querySelectorAll(".topic-card");
  const sections = document.querySelectorAll(".ref-section");

  if (!viewsInput || !minutesInput || !libraryMinutesInput || !btn || !results) {
    return;
  }

  const USD_TO_SAR = 3.75;
  const DAYS_PER_MONTH = 30;
  const MONTHS_PER_YEAR = 12;
  const MB_PER_MINUTE = 3; // متوسط الحجم بعد الضغط لكل دقيقة
  const EGRESS_COST_PER_GB_USD = 0.01; // تكلفة تقريبية لكل 1GB في سيناريو Wasabi/B2 + CDN

  function format(number) {
    return number.toLocaleString("en-US", {
      maximumFractionDigits: 2
    });
  }

  // initial section state: show summary
  sections.forEach((sec) => {
    if (sec.id === "summary") {
      sec.classList.add("active-section");
    } else {
      sec.classList.remove("active-section");
    }
  });

  // tabs behavior: show only selected section + active state + scroll
  topicCards.forEach((card) => {
    card.addEventListener("click", () => {
      const targetId = card.getAttribute("data-target");
      const target = document.getElementById(targetId);

      if (target) {
        sections.forEach((sec) => {
          if (sec.id === targetId) {
            sec.classList.add("active-section");
          } else {
            sec.classList.remove("active-section");
          }
        });

        target.scrollIntoView({ behavior: "smooth", block: "start" });
      }

      topicCards.forEach((c) => c.classList.remove("active"));
      card.classList.add("active");
    });
  });

  btn.addEventListener("click", () => {
    const viewsPerDay = Number(viewsInput.value) || 0;
    const minutesPerView = Number(minutesInput.value) || 0;
    const libraryMinutes = Number(libraryMinutesInput.value) || 0;

    if (viewsPerDay <= 0 || minutesPerView <= 0 || libraryMinutes <= 0) {
      results.textContent = "الرجاء إدخال قيم صحيحة أكبر من صفر في جميع الحقول.";
      return;
    }

    const totalMinutesPerDay = viewsPerDay * minutesPerView;
    const totalMinutesPerMonth = totalMinutesPerDay * DAYS_PER_MONTH;
    const totalMinutesPerYear = totalMinutesPerMonth * MONTHS_PER_YEAR;

    const unitsDelivery = totalMinutesPerMonth / 1000;
    const unitsStorage = libraryMinutes / 1000;

    // Cloudflare Stream
    const cfStreamDeliveryUSD = unitsDelivery * 1; // 1$ لكل 1000 دقيقة مشاهدة
    const cfStreamStorageUSD = unitsStorage * 5; // 5$ لكل 1000 دقيقة تخزين
    const cfStreamTotalUSD = cfStreamDeliveryUSD + cfStreamStorageUSD;

    const cfStreamDeliverySAR = cfStreamDeliveryUSD * USD_TO_SAR;
    const cfStreamStorageSAR = cfStreamStorageUSD * USD_TO_SAR;
    const cfStreamTotalSAR = cfStreamTotalUSD * USD_TO_SAR;

    const cfStreamTotalUSDPerDay = cfStreamTotalUSD / DAYS_PER_MONTH;
    const cfStreamTotalUSDPerYear = cfStreamTotalUSD * MONTHS_PER_YEAR;
    const cfStreamTotalSARPerDay = cfStreamTotalSAR / DAYS_PER_MONTH;
    const cfStreamTotalSARPerYear = cfStreamTotalSAR * MONTHS_PER_YEAR;

    // Wasabi/B2 + Cloudflare (نستخدم أرقام تقريبية من السيناريو)
    // نفترض:
    // - تخزين ≈ 1–5TB ⇒ 7–35$
    // - 20$ Cloudflare Pro
    // - 80$ تحويل (Transcoding)
    // - تكلفة Egress تقريبية مرتبطة بحجم المشاهدات: 0.01$ لكل 1GB
    const wasabiStorageUSD = 35;
    const wasabiTranscodeUSD = 80;
    const cfProUSD = 20;
    const totalGBPerMonth = (totalMinutesPerMonth * MB_PER_MINUTE) / 1024;
    const egressUSD = totalGBPerMonth * EGRESS_COST_PER_GB_USD;

    const wasabiBaseUSD = wasabiStorageUSD + wasabiTranscodeUSD + cfProUSD;
    const wasabiTotalUSD = wasabiBaseUSD + egressUSD;
    const wasabiTotalSAR = wasabiTotalUSD * USD_TO_SAR;

    const wasabiTotalUSDPerDay = wasabiTotalUSD / DAYS_PER_MONTH;
    const wasabiTotalUSDPerYear = wasabiTotalUSD * MONTHS_PER_YEAR;
    const wasabiTotalSARPerDay = wasabiTotalSAR / DAYS_PER_MONTH;
    const wasabiTotalSARPerYear = wasabiTotalSAR * MONTHS_PER_YEAR;

    results.innerHTML = `
      <h3>نتيجة تقريبية مفصلة للتكلفة (يومي / شهري / سنوي)</h3>
      <p>
        <strong>إجمالي الدقائق للمشاهدة:</strong>
        يوميًا: ${format(totalMinutesPerDay)} دقيقة،
        شهريًا: ${format(totalMinutesPerMonth)} دقيقة،
        سنويًا: ${format(totalMinutesPerYear)} دقيقة.
      </p>
      <div style="margin-top:0.6rem">
        <strong>Cloudflare Stream (رسميًا بالدقائق):</strong>
        <table class="calc-table">
          <thead>
            <tr>
              <th>البند</th>
              <th>يومي (دولار / ريال)</th>
              <th>شهري (دولار / ريال)</th>
              <th>سنوي (دولار / ريال)</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>الإجمالي (بث + تخزين)</td>
              <td>${format(cfStreamTotalUSDPerDay)}$ / ${format(cfStreamTotalSARPerDay)} ر.س</td>
              <td>${format(cfStreamTotalUSD)}$ / ${format(cfStreamTotalSAR)} ر.س</td>
              <td>${format(cfStreamTotalUSDPerYear)}$ / ${format(cfStreamTotalSARPerYear)} ر.س</td>
            </tr>
            <tr>
              <td>البث فقط (شهري)</td>
              <td colspan="3">${format(cfStreamDeliveryUSD)}$ / ${format(cfStreamDeliverySAR)} ر.س تقريبًا</td>
            </tr>
            <tr>
              <td>التخزين فقط (شهري)</td>
              <td colspan="3">${format(cfStreamStorageUSD)}$ / ${format(cfStreamStorageSAR)} ر.س تقريبًا</td>
            </tr>
          </tbody>
        </table>
      </div>
      <div style="margin-top:0.4rem">
        <strong>Wasabi/Backblaze + Cloudflare CDN (تقريبي):</strong>
        <table class="calc-table">
          <thead>
            <tr>
              <th>البند</th>
              <th>يومي (دولار / ريال)</th>
              <th>شهري (دولار / ريال)</th>
              <th>سنوي (دولار / ريال)</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>الإجمالي (تخزين + تحويل + CDN)</td>
              <td>${format(wasabiTotalUSDPerDay)}$ / ${format(wasabiTotalSARPerDay)} ر.س</td>
              <td>${format(wasabiTotalUSD)}$ / ${format(wasabiTotalSAR)} ر.س</td>
              <td>${format(wasabiTotalUSDPerYear)}$ / ${format(wasabiTotalSARPerYear)} ر.س</td>
            </tr>
            <tr>
              <td>التخزين التقريبي (شهري حتى 5TB)</td>
              <td colspan="3">حوالي ${format(wasabiStorageUSD)}$ / ${format(
                wasabiStorageUSD * USD_TO_SAR
              )} ر.س</td>
            </tr>
            <tr>
              <td>التحويل (Transcoding) التقريبي (شهري)</td>
              <td colspan="3">حوالي ${format(wasabiTranscodeUSD)}$ / ${format(
                wasabiTranscodeUSD * USD_TO_SAR
              )} ر.س</td>
            </tr>
            <tr>
              <td>Cloudflare Pro (شهري)</td>
              <td colspan="3">حوالي ${format(cfProUSD)}$ / ${format(
                cfProUSD * USD_TO_SAR
              )} ر.س</td>
            </tr>
            <tr>
              <td>نقل البيانات (Egress) التقريبي (شهري)</td>
              <td colspan="3">حوالي ${format(egressUSD)}$ / ${format(
                egressUSD * USD_TO_SAR
              )} ر.س (بحسب حجم المشاهدات)</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p style="margin-top:0.4rem;font-size:0.85rem;color:#9ca3af">
        هذه الأرقام تقريبية لتوضيح فرق الحجم بين الحلّين، وتعتمد على الأسعار الرسمية المعلنة حتى عام 2025.
        يجب دائمًا مراجعة صفحات التسعير الرسمية قبل اتخاذ القرار النهائي.
      </p>
    `;
  });
})();


