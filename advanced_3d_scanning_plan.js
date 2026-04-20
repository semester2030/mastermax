// Interactive section navigation
document.addEventListener('DOMContentLoaded', function() {
  const iconCards = document.querySelectorAll('.icon-card');
  const sections = document.querySelectorAll('.ref-section');

  // Set first section as active by default
  if (sections.length > 0) {
    sections[0].classList.add('active-section');
    const firstIcon = document.querySelector(`[data-section="${sections[0].id}"]`);
    if (firstIcon) {
      firstIcon.classList.add('active');
    }
  }

  iconCards.forEach(card => {
    card.addEventListener('click', function() {
      const targetSectionId = this.getAttribute('data-section');
      const targetSection = document.getElementById(targetSectionId);

      if (targetSection) {
        // Remove active class from all sections and icons
        sections.forEach(section => {
          section.classList.remove('active-section');
        });
        iconCards.forEach(icon => {
          icon.classList.remove('active');
        });

        // Add active class to clicked icon and target section
        this.classList.add('active');
        targetSection.classList.add('active-section');

        // Scroll to section smoothly
        targetSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });
});

// Cost Calculator Function
function calculateCosts() {
  const dailyVideos = parseInt(document.getElementById('daily-videos').value) || 0;
  const videoLength = parseFloat(document.getElementById('video-length').value) || 0;
  const gpuType = document.getElementById('gpu-type').value;

  if (dailyVideos === 0 || videoLength === 0) {
    alert('يرجى إدخال عدد المقاطع وطول كل مقطع');
    return;
  }

  // GPU Prices per hour
  const gpuPrices = {
    'h100-pcie': 1.99,
    'h100-sxm': 2.69,
    'a100-pcie': 1.19
  };

  const gpuPricePerHour = gpuPrices[gpuType];
  const processingTimePerVideo = 0.5; // 30 minutes = 0.5 hours (after optimization)
  const totalGpuHoursPerDay = dailyVideos * processingTimePerVideo;

  // Calculate GPU costs
  const gpuCostPerDay = totalGpuHoursPerDay * gpuPricePerHour;
  const gpuCostPerMonth = gpuCostPerDay * 30;
  const gpuCostPerYear = gpuCostPerDay * 365;

  // Storage costs (per GB per month)
  const videoSizeMB = 500; // Raw video size
  const modelSizeMB = 200; // 3D model size
  const totalSizePerVideoMB = videoSizeMB + modelSizeMB;
  const totalSizePerDayGB = (dailyVideos * totalSizePerVideoMB) / 1024;
  const totalSizePerMonthGB = totalSizePerDayGB * 30;
  const storagePricePerGB = 0.023; // AWS S3 Standard
  const storageCostPerDay = (totalSizePerDayGB * storagePricePerGB) / 30;
  const storageCostPerMonth = totalSizePerMonthGB * storagePricePerGB;
  const storageCostPerYear = storageCostPerMonth * 12;

  // Network costs (data transfer out)
  const downloadSizePerVideoMB = 200; // 3D model download
  const downloadSizePerDayGB = (dailyVideos * downloadSizePerVideoMB) / 1024;
  const downloadSizePerMonthGB = downloadSizePerDayGB * 30;
  const networkPricePerGB = 0.09; // AWS Data Transfer (first 10 TB)
  const networkCostPerDay = (downloadSizePerDayGB * networkPricePerGB) / 30;
  const networkCostPerMonth = downloadSizePerMonthGB * networkPricePerGB;
  const networkCostPerYear = networkCostPerMonth * 12;

  // Backend server costs (24/7)
  const backendPricePerHour = 0.0832; // t3.large
  const backendCostPerDay = backendPricePerHour * 24;
  const backendCostPerMonth = backendCostPerDay * 30;
  const backendCostPerYear = backendCostPerDay * 365;

  // Team salaries (optional)
  const techLeadSalary = parseFloat(document.getElementById('tech-lead-salary').value) || 0;
  const flutterDevCount = parseInt(document.getElementById('flutter-dev-count').value) || 0;
  const flutterDevSalary = parseFloat(document.getElementById('flutter-dev-salary').value) || 0;
  const backendDevCount = parseInt(document.getElementById('backend-dev-count').value) || 0;
  const backendDevSalary = parseFloat(document.getElementById('backend-dev-salary').value) || 0;
  const mlEngineerSalary = parseFloat(document.getElementById('ml-engineer-salary').value) || 0;
  const uiuxSalary = parseFloat(document.getElementById('uiux-salary').value) || 0;
  const devopsSalary = parseFloat(document.getElementById('devops-salary').value) || 0;
  const qaSalary = parseFloat(document.getElementById('qa-salary').value) || 0;

  // Calculate team costs
  const teamCostPerMonth = techLeadSalary + 
                          (flutterDevCount * flutterDevSalary) + 
                          (backendDevCount * backendDevSalary) + 
                          mlEngineerSalary + 
                          uiuxSalary + 
                          devopsSalary + 
                          qaSalary;
  const teamCostPerDay = teamCostPerMonth / 30;
  const teamCostPerYear = teamCostPerMonth * 12;

  // Total costs
  const totalCostPerDay = gpuCostPerDay + storageCostPerDay + networkCostPerDay + backendCostPerDay + teamCostPerDay;
  const totalCostPerMonth = gpuCostPerMonth + storageCostPerMonth + networkCostPerMonth + backendCostPerMonth + teamCostPerMonth;
  const totalCostPerYear = gpuCostPerYear + storageCostPerYear + networkCostPerYear + backendCostPerYear + teamCostPerYear;

  // Format numbers
  function formatCurrency(num) {
    return '$' + num.toFixed(2);
  }

  function formatNumber(num) {
    return num.toLocaleString('en-US', { maximumFractionDigits: 2 });
  }

  // Update GPU costs table
  const gpuTable = document.getElementById('gpu-costs-table');
  gpuTable.innerHTML = `
    <tr>
      <td>عدد ساعات GPU/يوم</td>
      <td>${formatNumber(totalGpuHoursPerDay)} ساعة</td>
      <td>${formatNumber(totalGpuHoursPerDay * 30)} ساعة</td>
      <td>${formatNumber(totalGpuHoursPerDay * 365)} ساعة</td>
    </tr>
    <tr>
      <td>سعر GPU/ساعة</td>
      <td>${formatCurrency(gpuPricePerHour)}</td>
      <td>${formatCurrency(gpuPricePerHour)}</td>
      <td>${formatCurrency(gpuPricePerHour)}</td>
    </tr>
    <tr class="highlight-row">
      <td><strong>التكلفة الإجمالية</strong></td>
      <td><strong>${formatCurrency(gpuCostPerDay)}</strong></td>
      <td><strong>${formatCurrency(gpuCostPerMonth)}</strong></td>
      <td><strong>${formatCurrency(gpuCostPerYear)}</strong></td>
    </tr>
  `;

  // Update Storage costs table
  const storageTable = document.getElementById('storage-costs-table');
  storageTable.innerHTML = `
    <tr>
      <td>حجم البيانات/يوم</td>
      <td>${formatNumber(totalSizePerDayGB)} GB</td>
      <td>${formatNumber(totalSizePerMonthGB)} GB</td>
      <td>${formatNumber(totalSizePerMonthGB * 12)} GB</td>
    </tr>
    <tr>
      <td>سعر التخزين/GB/شهر</td>
      <td>-</td>
      <td>${formatCurrency(storagePricePerGB)}</td>
      <td>${formatCurrency(storagePricePerGB)}</td>
    </tr>
    <tr class="highlight-row">
      <td><strong>التكلفة الإجمالية</strong></td>
      <td><strong>${formatCurrency(storageCostPerDay)}</strong></td>
      <td><strong>${formatCurrency(storageCostPerMonth)}</strong></td>
      <td><strong>${formatCurrency(storageCostPerYear)}</strong></td>
    </tr>
  `;

  // Update Network costs table
  const networkTable = document.getElementById('network-costs-table');
  networkTable.innerHTML = `
    <tr>
      <td>حجم البيانات المنقولة/يوم</td>
      <td>${formatNumber(downloadSizePerDayGB)} GB</td>
      <td>${formatNumber(downloadSizePerMonthGB)} GB</td>
      <td>${formatNumber(downloadSizePerMonthGB * 12)} GB</td>
    </tr>
    <tr>
      <td>سعر النقل/GB</td>
      <td>-</td>
      <td>${formatCurrency(networkPricePerGB)}</td>
      <td>${formatCurrency(networkPricePerGB)}</td>
    </tr>
    <tr class="highlight-row">
      <td><strong>التكلفة الإجمالية</strong></td>
      <td><strong>${formatCurrency(networkCostPerDay)}</strong></td>
      <td><strong>${formatCurrency(networkCostPerMonth)}</strong></td>
      <td><strong>${formatCurrency(networkCostPerYear)}</strong></td>
    </tr>
  `;

  // Update Backend costs table
  const backendTable = document.getElementById('backend-costs-table');
  backendTable.innerHTML = `
    <tr>
      <td>ساعات التشغيل/يوم</td>
      <td>24 ساعة</td>
      <td>720 ساعة</td>
      <td>8,760 ساعة</td>
    </tr>
    <tr>
      <td>سعر الساعة</td>
      <td>${formatCurrency(backendPricePerHour)}</td>
      <td>${formatCurrency(backendPricePerHour)}</td>
      <td>${formatCurrency(backendPricePerHour)}</td>
    </tr>
    <tr class="highlight-row">
      <td><strong>التكلفة الإجمالية</strong></td>
      <td><strong>${formatCurrency(backendCostPerDay)}</strong></td>
      <td><strong>${formatCurrency(backendCostPerMonth)}</strong></td>
      <td><strong>${formatCurrency(backendCostPerYear)}</strong></td>
    </tr>
  `;

  // Update Team salary table
  const teamTable = document.getElementById('team-salary-table');
  const teamRows = [];
  if (techLeadSalary > 0) {
    teamRows.push(`<tr><td>Tech Lead</td><td>1</td><td>${formatCurrency(techLeadSalary)}</td><td>${formatCurrency(techLeadSalary / 30)}</td><td>${formatCurrency(techLeadSalary)}</td><td>${formatCurrency(techLeadSalary * 12)}</td></tr>`);
  }
  if (flutterDevCount > 0 && flutterDevSalary > 0) {
    const total = flutterDevCount * flutterDevSalary;
    teamRows.push(`<tr><td>Senior Flutter Developer</td><td>${flutterDevCount}</td><td>${formatCurrency(flutterDevSalary)}</td><td>${formatCurrency(total / 30)}</td><td>${formatCurrency(total)}</td><td>${formatCurrency(total * 12)}</td></tr>`);
  }
  if (backendDevCount > 0 && backendDevSalary > 0) {
    const total = backendDevCount * backendDevSalary;
    teamRows.push(`<tr><td>Backend Developer</td><td>${backendDevCount}</td><td>${formatCurrency(backendDevSalary)}</td><td>${formatCurrency(total / 30)}</td><td>${formatCurrency(total)}</td><td>${formatCurrency(total * 12)}</td></tr>`);
  }
  if (mlEngineerSalary > 0) {
    teamRows.push(`<tr><td>ML Engineer</td><td>1</td><td>${formatCurrency(mlEngineerSalary)}</td><td>${formatCurrency(mlEngineerSalary / 30)}</td><td>${formatCurrency(mlEngineerSalary)}</td><td>${formatCurrency(mlEngineerSalary * 12)}</td></tr>`);
  }
  if (uiuxSalary > 0) {
    teamRows.push(`<tr><td>UI/UX Designer</td><td>1</td><td>${formatCurrency(uiuxSalary)}</td><td>${formatCurrency(uiuxSalary / 30)}</td><td>${formatCurrency(uiuxSalary)}</td><td>${formatCurrency(uiuxSalary * 12)}</td></tr>`);
  }
  if (devopsSalary > 0) {
    teamRows.push(`<tr><td>DevOps Engineer</td><td>1</td><td>${formatCurrency(devopsSalary)}</td><td>${formatCurrency(devopsSalary / 30)}</td><td>${formatCurrency(devopsSalary)}</td><td>${formatCurrency(devopsSalary * 12)}</td></tr>`);
  }
  if (qaSalary > 0) {
    teamRows.push(`<tr><td>QA Engineer</td><td>1</td><td>${formatCurrency(qaSalary)}</td><td>${formatCurrency(qaSalary / 30)}</td><td>${formatCurrency(qaSalary)}</td><td>${formatCurrency(qaSalary * 12)}</td></tr>`);
  }
  
  if (teamRows.length > 0) {
    teamRows.push(`<tr class="highlight-row"><td><strong>إجمالي رواتب الفريق</strong></td><td>-</td><td>-</td><td><strong>${formatCurrency(teamCostPerDay)}</strong></td><td><strong>${formatCurrency(teamCostPerMonth)}</strong></td><td><strong>${formatCurrency(teamCostPerYear)}</strong></td></tr>`);
    teamTable.innerHTML = teamRows.join('');
  } else {
    teamTable.innerHTML = '<tr><td colspan="6" style="text-align: center; color: #64748b;">لم يتم إدخال رواتب الفريق (اختياري)</td></tr>';
  }

  // Update Total costs table
  const totalTable = document.getElementById('total-costs-table');
  totalTable.innerHTML = `
    <tr>
      <td><strong>GPUs</strong></td>
      <td>${formatCurrency(gpuCostPerDay)}</td>
      <td>${formatCurrency(gpuCostPerMonth)}</td>
      <td>${formatCurrency(gpuCostPerYear)}</td>
    </tr>
    <tr>
      <td><strong>Storage</strong></td>
      <td>${formatCurrency(storageCostPerDay)}</td>
      <td>${formatCurrency(storageCostPerMonth)}</td>
      <td>${formatCurrency(storageCostPerYear)}</td>
    </tr>
    <tr>
      <td><strong>Network</strong></td>
      <td>${formatCurrency(networkCostPerDay)}</td>
      <td>${formatCurrency(networkCostPerMonth)}</td>
      <td>${formatCurrency(networkCostPerYear)}</td>
    </tr>
    <tr>
      <td><strong>Backend</strong></td>
      <td>${formatCurrency(backendCostPerDay)}</td>
      <td>${formatCurrency(backendCostPerMonth)}</td>
      <td>${formatCurrency(backendCostPerYear)}</td>
    </tr>
    ${teamCostPerMonth > 0 ? `<tr>
      <td><strong>رواتب الفريق</strong></td>
      <td>${formatCurrency(teamCostPerDay)}</td>
      <td>${formatCurrency(teamCostPerMonth)}</td>
      <td>${formatCurrency(teamCostPerYear)}</td>
    </tr>` : ''}
    <tr class="highlight-row">
      <td><strong>الإجمالي النهائي</strong></td>
      <td><strong>${formatCurrency(totalCostPerDay)}</strong></td>
      <td><strong>${formatCurrency(totalCostPerMonth)}</strong></td>
      <td><strong>${formatCurrency(totalCostPerYear)}</strong></td>
    </tr>
  `;

  // Show results
  document.getElementById('cost-results').style.display = 'block';
  document.getElementById('cost-results').scrollIntoView({ behavior: 'smooth', block: 'start' });
}

