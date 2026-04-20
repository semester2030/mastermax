// Navigation System - Show/Hide Sections
(() => {
  const iconCards = document.querySelectorAll('.icon-card');
  const sections = document.querySelectorAll('.ref-section');

  // Initialize: Show first section
  if (sections.length > 0) {
    sections[0].classList.add('active-section');
    iconCards[0]?.classList.add('active');
  }

  // Handle icon clicks
  iconCards.forEach((iconCard) => {
    iconCard.addEventListener('click', () => {
      const targetSection = iconCard.getAttribute('data-section');

      // Remove active from all
      iconCards.forEach((card) => card.classList.remove('active'));
      sections.forEach((section) => section.classList.remove('active-section'));

      // Add active to clicked
      iconCard.classList.add('active');
      const targetElement = document.getElementById(targetSection);
      if (targetElement) {
        targetElement.classList.add('active-section');
        // Smooth scroll to section
        targetElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });

  // Handle hash navigation (if user comes with #section)
  const hash = window.location.hash;
  if (hash) {
    const targetId = hash.substring(1);
    const targetSection = document.getElementById(targetId);
    const targetIcon = document.querySelector(`[data-section="${targetId}"]`);
    
    if (targetSection && targetIcon) {
      iconCards.forEach((card) => card.classList.remove('active'));
      sections.forEach((section) => section.classList.remove('active-section'));
      
      targetIcon.classList.add('active');
      targetSection.classList.add('active-section');
      setTimeout(() => {
        targetSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }, 100);
    }
  }
})();

// Smooth scroll for internal links
document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
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
  entries.forEach((entry) => {
    if (entry.isIntersecting) {
      entry.target.style.opacity = '1';
      entry.target.style.transform = 'translateY(0)';
    }
  });
}, observerOptions);

// Observe elements for animation
document.querySelectorAll('.comparison-card, .reason-card, .req-card, .step-card').forEach((el) => {
  el.style.opacity = '0';
  el.style.transform = 'translateY(20px)';
  el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
  observer.observe(el);
});

// Add copy functionality to code blocks
document.querySelectorAll('pre code').forEach((codeBlock) => {
  const pre = codeBlock.parentElement;
  if (pre && !pre.querySelector('.copy-btn')) {
    const copyBtn = document.createElement('button');
    copyBtn.className = 'copy-btn';
    copyBtn.innerHTML = '<i class="fas fa-copy"></i> نسخ';
    copyBtn.style.cssText = `
      position: absolute;
      top: 10px;
      left: 10px;
      background: var(--primary-color);
      color: white;
      border: none;
      padding: 5px 10px;
      border-radius: 5px;
      cursor: pointer;
      font-size: 0.85rem;
      opacity: 0;
      transition: opacity 0.3s ease;
    `;
    
    pre.style.position = 'relative';
    pre.appendChild(copyBtn);
    
    pre.addEventListener('mouseenter', () => {
      copyBtn.style.opacity = '1';
    });
    
    pre.addEventListener('mouseleave', () => {
      copyBtn.style.opacity = '0';
    });
    
    copyBtn.addEventListener('click', async () => {
      const text = codeBlock.textContent;
      try {
        await navigator.clipboard.writeText(text);
        copyBtn.innerHTML = '<i class="fas fa-check"></i> تم النسخ!';
        setTimeout(() => {
          copyBtn.innerHTML = '<i class="fas fa-copy"></i> نسخ';
        }, 2000);
      } catch (err) {
        console.error('Failed to copy:', err);
      }
    });
  }
});

// Add table row highlight on hover
document.querySelectorAll('.data-table tbody tr').forEach((row) => {
  row.addEventListener('mouseenter', function() {
    this.style.backgroundColor = '#F8FAFC';
    this.style.transition = 'background-color 0.2s ease';
  });
  
  row.addEventListener('mouseleave', function() {
    this.style.backgroundColor = '';
  });
});

// Add print functionality
const printBtn = document.createElement('button');
printBtn.innerHTML = '<i class="fas fa-print"></i> طباعة';
printBtn.style.cssText = `
  position: fixed;
  bottom: 20px;
  left: 20px;
  background: var(--primary-color);
  color: white;
  border: none;
  padding: 12px 20px;
  border-radius: 50px;
  cursor: pointer;
  box-shadow: 0 4px 6px rgba(0,0,0,0.3);
  z-index: 1000;
  font-size: 1rem;
  transition: all 0.3s ease;
`;

printBtn.addEventListener('mouseenter', () => {
  printBtn.style.transform = 'scale(1.05)';
  printBtn.style.boxShadow = '0 6px 12px rgba(0,0,0,0.4)';
});

printBtn.addEventListener('mouseleave', () => {
  printBtn.style.transform = 'scale(1)';
  printBtn.style.boxShadow = '0 4px 6px rgba(0,0,0,0.3)';
});

printBtn.addEventListener('click', () => {
  window.print();
});

document.body.appendChild(printBtn);

// Add back to top button
const backToTopBtn = document.createElement('button');
backToTopBtn.innerHTML = '<i class="fas fa-arrow-up"></i>';
backToTopBtn.style.cssText = `
  position: fixed;
  bottom: 80px;
  left: 20px;
  background: var(--secondary-color);
  color: white;
  border: none;
  width: 50px;
  height: 50px;
  border-radius: 50%;
  cursor: pointer;
  box-shadow: 0 4px 6px rgba(0,0,0,0.3);
  z-index: 1000;
  font-size: 1.2rem;
  opacity: 0;
  transition: all 0.3s ease;
  display: flex;
  align-items: center;
  justify-content: center;
`;

window.addEventListener('scroll', () => {
  if (window.scrollY > 300) {
    backToTopBtn.style.opacity = '1';
  } else {
    backToTopBtn.style.opacity = '0';
  }
});

backToTopBtn.addEventListener('click', () => {
  window.scrollTo({ top: 0, behavior: 'smooth' });
});

backToTopBtn.addEventListener('mouseenter', () => {
  backToTopBtn.style.transform = 'scale(1.1)';
  backToTopBtn.style.boxShadow = '0 6px 12px rgba(0,0,0,0.4)';
});

backToTopBtn.addEventListener('mouseleave', () => {
  backToTopBtn.style.transform = 'scale(1)';
  backToTopBtn.style.boxShadow = '0 4px 6px rgba(0,0,0,0.3)';
});

document.body.appendChild(backToTopBtn);

// Add loading animation
window.addEventListener('load', () => {
  document.body.style.opacity = '0';
  document.body.style.transition = 'opacity 0.5s ease';
  
  setTimeout(() => {
    document.body.style.opacity = '1';
  }, 100);
});

// Add search functionality (optional - can be enhanced)
const searchInput = document.createElement('input');
searchInput.type = 'text';
searchInput.placeholder = 'بحث في المحتوى...';
searchInput.style.cssText = `
  position: fixed;
  top: 20px;
  right: 20px;
  padding: 10px 15px;
  border: 2px solid var(--primary-color);
  border-radius: 25px;
  font-size: 1rem;
  width: 250px;
  z-index: 1000;
  direction: rtl;
`;

// Optional: Add search functionality
// searchInput.addEventListener('input', (e) => {
//   const searchTerm = e.target.value.toLowerCase();
//   // Implement search logic here
// });

// Uncomment to enable search
// document.body.appendChild(searchInput);

console.log('✅ Mastermax Video Services Guide - Loaded Successfully');

