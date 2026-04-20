(() => {
  'use strict';

  // Tab Navigation
  const iconCards = document.querySelectorAll('.icon-card');
  const sections = document.querySelectorAll('.ref-section');

  iconCards.forEach(card => {
    card.addEventListener('click', () => {
      const targetSection = card.getAttribute('data-section');
      console.log('Clicked icon:', targetSection);
      
      // Remove active class from all cards and sections
      iconCards.forEach(c => c.classList.remove('active'));
      sections.forEach(s => {
        s.classList.remove('active-section');
        s.style.display = 'none';
      });
      
      // Add active class to clicked card and corresponding section
      card.classList.add('active');
      const targetElement = document.getElementById(targetSection);
      console.log('Target element:', targetElement);
      
      if (targetElement) {
        targetElement.classList.add('active-section');
        // Force display block to ensure visibility
        targetElement.style.display = 'block';
        targetElement.style.visibility = 'visible';
        targetElement.style.opacity = '1';
        console.log('Section activated:', targetSection);
        
        // Small delay before scroll to ensure element is visible
        setTimeout(() => {
          targetElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }, 100);
      } else {
        console.error('Section not found:', targetSection);
        alert('القسم غير موجود: ' + targetSection);
      }
    });
  });

  // Pricing Calculator
  const calcBtn = document.getElementById('calc-pricing-btn');
  const pricingResults = document.getElementById('pricing-results');

  if (calcBtn && pricingResults) {
    calcBtn.addEventListener('click', () => {
      const planSelect = document.getElementById('plan-select');
      const spacesCount = parseInt(document.getElementById('spaces-count').value) || 0;
      const floorPlans = parseInt(document.getElementById('floor-plans').value) || 0;

      if (!planSelect) return;

      const plan = planSelect.value;
      const USD_TO_SAR = 3.75;

      // Plan pricing (monthly, annual billing)
      const planPrices = {
        free: { monthly: 0, annual: 0 },
        starter: { monthly: 12, annual: 144 },
        professional: { monthly: 58, annual: 696 },
        business: { monthly: 296, annual: 3552 }
      };

      const selectedPlan = planPrices[plan];
      if (!selectedPlan) {
        pricingResults.innerHTML = '<p style="color: #ef4444;">الرجاء اختيار خطة صحيحة</p>';
        return;
      }

      // Calculate floor plans cost
      let floorPlansCost = 0;
      if (floorPlans > 0) {
        if (plan === 'starter') {
          floorPlansCost = floorPlans * 19.99;
        } else if (plan === 'professional' || plan === 'business') {
          floorPlansCost = floorPlans * 14.99;
        }
      }

      const monthlyUSD = selectedPlan.monthly + floorPlansCost;
      const annualUSD = selectedPlan.annual + (floorPlansCost * 12);
      const monthlySAR = monthlyUSD * USD_TO_SAR;
      const annualSAR = annualUSD * USD_TO_SAR;

      // Check if spaces count is within plan limits
      const planLimits = {
        free: { min: 1, max: 1 },
        starter: { min: 5, max: 20 },
        professional: { min: 20, max: 150 },
        business: { min: 100, max: 300 }
      };

      const limit = planLimits[plan];
      let spacesWarning = '';
      if (spacesCount < limit.min || spacesCount > limit.max) {
        spacesWarning = `<div class="warning" style="margin-top: 15px; padding: 15px;">
          <p><strong>تحذير:</strong> عدد Active Spaces المطلوب (${spacesCount}) خارج نطاق الخطة ${plan} (${limit.min}-${limit.max}). قد تحتاج لترقية الخطة.</p>
        </div>`;
      }

      pricingResults.innerHTML = `
        <h3 style="color: #1e3a8a; margin-bottom: 15px;">
          <i class="fas fa-calculator"></i> نتائج الحساب
        </h3>
        <div style="background: #f8fafc; padding: 20px; border-radius: 10px; margin-bottom: 15px;">
          <p><strong>الخطة المختارة:</strong> ${planSelect.options[planSelect.selectedIndex].text}</p>
          <p><strong>عدد Active Spaces:</strong> ${spacesCount}</p>
          <p><strong>عدد Floor Plans شهرياً:</strong> ${floorPlans}</p>
        </div>
        <table class="data-table" style="margin-top: 15px;">
          <thead>
            <tr>
              <th>البند</th>
              <th>شهري (USD)</th>
              <th>شهري (SAR)</th>
              <th>سنوي (USD)</th>
              <th>سنوي (SAR)</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>الاشتراك الأساسي</td>
              <td>$${selectedPlan.monthly.toFixed(2)}</td>
              <td>${(selectedPlan.monthly * USD_TO_SAR).toFixed(2)} ر.س</td>
              <td>$${selectedPlan.annual.toFixed(2)}</td>
              <td>${(selectedPlan.annual * USD_TO_SAR).toFixed(2)} ر.س</td>
            </tr>
            ${floorPlans > 0 ? `
            <tr>
              <td>Floor Plans (${floorPlans}/شهر)</td>
              <td>$${floorPlansCost.toFixed(2)}</td>
              <td>${(floorPlansCost * USD_TO_SAR).toFixed(2)} ر.س</td>
              <td>$${(floorPlansCost * 12).toFixed(2)}</td>
              <td>${(floorPlansCost * 12 * USD_TO_SAR).toFixed(2)} ر.س</td>
            </tr>
            ` : ''}
            <tr class="highlight-row">
              <td><strong>الإجمالي</strong></td>
              <td><strong>$${monthlyUSD.toFixed(2)}</strong></td>
              <td><strong>${monthlySAR.toFixed(2)} ر.س</strong></td>
              <td><strong>$${annualUSD.toFixed(2)}</strong></td>
              <td><strong>${annualSAR.toFixed(2)} ر.س</strong></td>
            </tr>
          </tbody>
        </table>
        ${spacesWarning}
        <div class="info" style="margin-top: 15px;">
          <strong>ملاحظة:</strong> هذه الأرقام تقريبية ومبنية على أسعار Matterport الرسمية حتى عام 2025. 
          يجب مراجعة الصفحة الرسمية للتسعير قبل اتخاذ القرار النهائي.
        </div>
      `;
    });
  }

  // Set first section as active on load
  if (sections.length > 0) {
    sections[0].classList.add('active-section');
  }
  if (iconCards.length > 0) {
    iconCards[0].classList.add('active');
  }

  // Smooth scroll for anchor links
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      e.preventDefault();
      const target = document.querySelector(this.getAttribute('href'));
      if (target) {
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });

  // Add animation on scroll
  const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.style.opacity = '1';
        entry.target.style.transform = 'translateY(0)';
      }
    });
  }, observerOptions);

  // Observe cards and sections
  document.querySelectorAll('.card, .evidence-item, .method-card').forEach(el => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(20px)';
    el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
    observer.observe(el);
  });

})();

